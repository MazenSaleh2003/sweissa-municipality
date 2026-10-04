-- Run once in SQL Editor after the account has signed in.
-- Replace the placeholder with the UUID displayed on that account's Account page.
-- This grants access to all resident records; verify the account first.
do $$
declare target uuid := '00000000-0000-0000-0000-000000000000';
begin
  if target = '00000000-0000-0000-0000-000000000000' then
    raise exception 'Replace the placeholder with the verified administrator account UUID';
  end if;
  if exists(select 1 from public.staff_members where role = 'admin') then
    raise exception 'Administrator already exists; use the app to manage additional staff';
  end if;
  insert into public.staff_members(user_id,role) values(target,'admin');
  insert into public.role_audit(actor_id,target_id,action) values(null,target,'bootstrap_admin');
end $$;
