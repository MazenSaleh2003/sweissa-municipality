-- Additive migration from the original requests schema. Run as database owner.
begin;

create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);
insert into public.departments(name) values ('الصيانة'),('الأشغال'),('النظافة'),('الإدارة') on conflict do nothing;

create table if not exists public.staff_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('staff','admin')),
  department_id uuid references public.departments(id),
  created_at timestamptz not null default now(),
  check (role = 'admin' or department_id is not null)
);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.staff_members where user_id = auth.uid() and role = 'admin');
$$;
create or replace function public.can_manage_department(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.staff_members where user_id = auth.uid()
    and (role = 'admin' or department_id = target));
$$;
revoke all on function public.is_admin(), public.can_manage_department(uuid) from public;
grant execute on function public.is_admin(), public.can_manage_department(uuid) to authenticated;

create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  resident_id uuid not null references auth.users(id) on delete cascade,
  request_type text not null check(request_type in ('issue_report','service_request')),
  category text not null,
  description text not null,
  location_text text,
  contact_phone text,
  has_photo boolean not null default false,
  status text not null default 'received' check(status in ('received','in_progress','resolved','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.requests add column if not exists department_id uuid references public.departments(id);
alter table public.requests add column if not exists latitude double precision;
alter table public.requests add column if not exists longitude double precision;
alter table public.requests add column if not exists photo_path text;
alter table public.requests add column if not exists staff_note text;
alter table public.requests add column if not exists submission_fingerprint text check(submission_fingerprint is null or submission_fingerprint ~ '^[a-f0-9]{64}$');
alter table public.requests add constraint requests_coordinates check (
  (latitude is null and longitude is null) or
  (latitude is not null and longitude is not null and latitude between -90 and 90 and longitude between -180 and 180)
);
-- Validate new submissions in the INSERT trigger without preventing staff from
-- updating legacy requests whose original descriptions were shorter.
alter table public.requests add constraint requests_photo_owner check (
  photo_path is null or photo_path in (
    resident_id::text || '/' || id::text || '/photo.jpg',
    resident_id::text || '/' || id::text || '/photo.png',
    resident_id::text || '/' || id::text || '/photo.webp'
  )
);

create table public.request_history (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.requests(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  status text not null,
  note text,
  created_at timestamptz not null default now()
);

create or replace function public.prepare_request() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if char_length(new.description) not between 10 and 4000 or char_length(new.category) not between 1 and 100
      or coalesce(char_length(new.location_text),0) > 500 or coalesce(char_length(new.contact_phone),0) > 40 then
      raise exception 'Invalid request details' using errcode = '23514';
    end if;
    if new.photo_path is not null and not exists(select 1 from storage.objects where bucket_id = 'request-photos' and name = new.photo_path) then
      raise exception 'Photo must be uploaded before submission' using errcode = '23514';
    end if;
    -- New requests always start received. Department routing is server controlled.
    new.status := 'received'; new.staff_note := null;
    new.created_at := now(); new.updated_at := now();
    select id into new.department_id from public.departments where name = case
      when new.category in ('إنارة الشوارع','مياه') then 'الصيانة'
      when new.category in ('الطرق والحفر') then 'الأشغال'
      when new.category = 'النفايات' then 'النظافة' else 'الإدارة' end;
  else
    new.updated_at := now();
  end if;
  new.has_photo := new.photo_path is not null;
  return new;
end; $$;
create trigger prepare_request before insert or update on public.requests for each row execute function public.prepare_request();

create or replace function public.log_request_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    insert into public.request_history(request_id,actor_id,status,note) values(new.id,auth.uid(),new.status,null);
  elsif new.status is distinct from old.status or new.staff_note is distinct from old.staff_note or new.department_id is distinct from old.department_id then
    insert into public.request_history(request_id,actor_id,status,note) values(new.id,auth.uid(),new.status,new.staff_note);
  end if;
  return new;
end; $$;
create trigger log_request_change after insert or update on public.requests for each row execute function public.log_request_change();

update public.requests set department_id = (select id from public.departments where name = 'الإدارة') where department_id is null;

alter table public.departments enable row level security;
alter table public.staff_members enable row level security;
alter table public.requests enable row level security;
alter table public.request_history enable row level security;
drop policy if exists "Residents can create their own requests" on public.requests;
drop policy if exists "Residents can view their own requests" on public.requests;
drop policy if exists "Residents can update their own received requests" on public.requests;
create policy departments_read on public.departments for select to authenticated using(true);
create policy membership_read on public.staff_members for select to authenticated using(user_id = auth.uid() or public.is_admin());
create policy requests_read on public.requests for select to authenticated using(resident_id = auth.uid() or public.can_manage_department(department_id));
create policy requests_insert on public.requests for insert to authenticated with check(resident_id = auth.uid() and status = 'received');
create policy history_read on public.request_history for select to authenticated using(exists(
  select 1 from public.requests r where r.id = request_id and (r.resident_id = auth.uid() or public.can_manage_department(r.department_id))
));
revoke all on public.departments, public.staff_members, public.requests, public.request_history from anon, authenticated;
grant select on public.departments, public.staff_members, public.requests, public.request_history to authenticated;
grant insert(id,resident_id,request_type,category,description,location_text,contact_phone,latitude,longitude,photo_path,submission_fingerprint) on public.requests to authenticated;

create or replace function public.update_request(target_id uuid, next_status text, note text default null, assigned_department uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.requests;
begin
  select * into r from public.requests where id = target_id for update;
  if r.id is null or not public.can_manage_department(r.department_id) then raise exception 'Not authorized' using errcode = '42501'; end if;
  if next_status not in ('received','in_progress','resolved','rejected') then raise exception 'Invalid status'; end if;
  if char_length(coalesce(note,'')) > 4000 then raise exception 'Note too long'; end if;
  if assigned_department is not null and assigned_department is distinct from r.department_id and not public.is_admin() then
    raise exception 'Only administrators assign departments' using errcode = '42501';
  end if;
  update public.requests set status = next_status, staff_note = nullif(trim(note),''),
    department_id = coalesce(assigned_department,department_id) where id = target_id;
end; $$;

create table public.role_audit (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  target_id uuid not null,
  action text not null,
  created_at timestamptz not null default now()
);
alter table public.role_audit enable row level security;
create policy role_audit_read on public.role_audit for select to authenticated using(public.is_admin());
revoke all on public.role_audit from anon, authenticated;
grant select on public.role_audit to authenticated;

create or replace function public.manage_member(target_id uuid, new_role text, assigned_department uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'Not authorized' using errcode = '42501'; end if;
  -- Serialize membership changes; preserve the final administrator.
  perform pg_advisory_xact_lock(73104001);
  if exists(select 1 from public.staff_members where user_id = target_id and role = 'admin')
    and new_role <> 'admin' and (select count(*) from public.staff_members where role = 'admin') <= 1 then
    raise exception 'Cannot remove the last administrator';
  end if;
  if new_role = 'resident' then delete from public.staff_members where user_id = target_id;
  elsif new_role in ('staff','admin') then
    insert into public.staff_members(user_id,role,department_id) values(target_id,new_role,assigned_department)
      on conflict(user_id) do update set role = excluded.role,department_id = excluded.department_id;
  else raise exception 'Invalid role'; end if;
  insert into public.role_audit(actor_id,target_id,action) values(auth.uid(),target_id,new_role);
end; $$;

-- One typed content collection supports public announcements, events, projects,
-- collection schedules, and official contact details. Nothing is seeded as fact.
create table public.public_content (
  id uuid primary key default gen_random_uuid(),
  kind text not null check(kind in ('announcement','event','project','waste_schedule','contact')),
  title text not null check(char_length(title) between 1 and 200),
  body text not null default '' check(char_length(body) <= 10000),
  location_text text,
  starts_at timestamptz,
  progress integer check(progress between 0 and 100),
  budget numeric(14,2) check(budget >= 0),
  currency text not null default 'USD' check(currency in ('USD','LBP','EUR')),
  phone text check(phone is null or phone ~ '^\+?[0-9]{6,15}$'),
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create or replace function public.touch_content() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end; $$;
revoke all on function public.touch_content() from public;
create trigger touch_content before update on public.public_content for each row execute function public.touch_content();
alter table public.public_content enable row level security;
create policy content_public on public.public_content for select to anon,authenticated using(published);
create policy content_admin on public.public_content for all to authenticated using(public.is_admin()) with check(public.is_admin());
revoke all on public.public_content from anon,authenticated;
grant select on public.public_content to anon,authenticated;
grant insert,update,delete on public.public_content to authenticated;

create table public.polls (
  id uuid primary key default gen_random_uuid(),
  question text not null check(char_length(question) between 1 and 500),
  options jsonb not null check(jsonb_typeof(options) = 'array' and jsonb_array_length(options) between 2 and 8),
  closes_at timestamptz not null,
  published boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.poll_votes (
  poll_id uuid not null references public.polls(id) on delete cascade,
  voter_id uuid not null references auth.users(id) on delete cascade,
  option_index integer not null check(option_index >= 0),
  created_at timestamptz not null default now(),
  primary key(poll_id,voter_id)
);
create or replace function public.validate_poll() returns trigger language plpgsql set search_path = '' as $$
declare item jsonb;
begin
  for item in select value from jsonb_array_elements(new.options) loop
    if jsonb_typeof(item) <> 'string' or char_length(item #>> '{}') not between 1 and 200 then raise exception 'Invalid poll option'; end if;
  end loop;
  if (select count(distinct value) from jsonb_array_elements(new.options)) <> jsonb_array_length(new.options) then raise exception 'Duplicate poll options'; end if;
  return new;
end; $$;
revoke all on function public.validate_poll() from public;
create trigger validate_poll before insert on public.polls for each row execute function public.validate_poll();
create or replace function public.validate_vote() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- Lock prevents a close/options edit racing a vote.
  perform 1 from public.polls where id = new.poll_id and published and closes_at > now()
    and new.option_index < jsonb_array_length(options) for share;
  if not found then raise exception 'Poll closed or invalid option'; end if;
  return new;
end; $$;
create trigger validate_vote before insert on public.poll_votes for each row execute function public.validate_vote();
alter table public.polls enable row level security;
alter table public.poll_votes enable row level security;
create policy polls_public on public.polls for select to anon,authenticated using(published);
create policy polls_admin on public.polls for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy votes_read on public.poll_votes for select to authenticated using(voter_id = auth.uid());
create policy votes_insert on public.poll_votes for insert to authenticated with check(voter_id = auth.uid());
revoke all on public.polls,public.poll_votes from anon,authenticated;
grant select on public.polls to anon,authenticated;
grant insert,delete on public.polls to authenticated;
grant select,insert on public.poll_votes to authenticated;
create or replace function public.poll_results(target_id uuid)
returns table(option_index integer,votes bigint) language sql stable security definer set search_path = '' as $$
  select v.option_index,count(*) from public.poll_votes v join public.polls p on p.id = v.poll_id
  where p.id = target_id and p.published group by v.option_index;
$$;

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  resident_id uuid not null references auth.users(id) on delete cascade,
  title text not null check(char_length(title) between 1 and 200),
  amount numeric(14,2) not null check(amount > 0),
  currency text not null default 'USD' check(currency in ('USD','LBP','EUR')),
  status text not null default 'unpaid' check(status in ('unpaid','paid')),
  payment_reference text,
  verified_by uuid references auth.users(id) on delete set null,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.invoices enable row level security;
create policy invoices_read on public.invoices for select to authenticated using(resident_id = auth.uid() or public.is_admin());
create policy invoices_insert on public.invoices for insert to authenticated with check(public.is_admin() and status = 'unpaid');
revoke all on public.invoices from anon,authenticated;
grant select on public.invoices to authenticated;
grant insert(resident_id,title,amount,currency) on public.invoices to authenticated;
create or replace function public.record_payment(target_id uuid, receipt_reference text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'Not authorized' using errcode = '42501'; end if;
  if char_length(trim(receipt_reference)) not between 3 and 200 or receipt_reference is null then raise exception 'Receipt reference required'; end if;
  update public.invoices set status = 'paid',payment_reference = trim(receipt_reference),verified_by = auth.uid(),paid_at = now()
    where id = target_id and status = 'unpaid';
  if not found then raise exception 'Invoice unavailable or already paid'; end if;
end; $$;

-- Restrict RPC execution explicitly: PostgreSQL otherwise grants PUBLIC execute.
revoke all on function public.update_request(uuid,text,text,uuid),public.manage_member(uuid,text,uuid),public.record_payment(uuid,text),public.poll_results(uuid) from public;
grant execute on function public.update_request(uuid,text,text,uuid),public.manage_member(uuid,text,uuid),public.record_payment(uuid,text) to authenticated;
grant execute on function public.poll_results(uuid) to anon,authenticated;
revoke all on function public.prepare_request(),public.log_request_change(),public.validate_vote() from public;

create index requests_resident_created on public.requests(resident_id,created_at desc);
create index requests_department_status on public.requests(department_id,status,created_at desc);
create index history_request_created on public.request_history(request_id,created_at);
create index content_kind_created on public.public_content(kind,created_at desc) where published;
create index invoices_resident on public.invoices(resident_id,created_at desc);

create or replace function public.request_metrics() returns jsonb
language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object('total',count(*),'received',count(*) filter(where status='received'),
    'in_progress',count(*) filter(where status='in_progress'),'resolved',count(*) filter(where status='resolved'),
    'rejected',count(*) filter(where status='rejected')) from public.requests
  where public.can_manage_department(department_id);
$$;
revoke all on function public.request_metrics() from public;
grant execute on function public.request_metrics() to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('request-photos','request-photos',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public = false,file_size_limit = excluded.file_size_limit,allowed_mime_types = excluded.allowed_mime_types;
create policy request_photos_insert on storage.objects for insert to authenticated with check(
  bucket_id = 'request-photos' and (storage.foldername(name))[1] = auth.uid()::text
  and not exists(select 1 from public.requests r where r.photo_path = name)
);
create policy request_photos_read on storage.objects for select to authenticated using(
  bucket_id = 'request-photos' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists(select 1 from public.requests r where r.photo_path = name and public.can_manage_department(r.department_id))
  )
);
create policy request_photos_update on storage.objects for update to authenticated using(
  bucket_id = 'request-photos' and (storage.foldername(name))[1] = auth.uid()::text
  and not exists(select 1 from public.requests r where r.photo_path = name)
) with check(bucket_id = 'request-photos' and (storage.foldername(name))[1] = auth.uid()::text
  and not exists(select 1 from public.requests r where r.photo_path = name));
create policy request_photos_delete on storage.objects for delete to authenticated using(
  bucket_id = 'request-photos' and (storage.foldername(name))[1] = auth.uid()::text
  and not exists(select 1 from public.requests r where r.photo_path = name)
);
commit;
