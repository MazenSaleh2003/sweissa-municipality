-- Sweissa Municipality: resident reports and service requests
-- Run this once in Supabase Dashboard > SQL Editor > New query.

create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  resident_id uuid not null references auth.users(id) on delete cascade,
  request_type text not null check (request_type in ('issue_report', 'service_request')),
  category text not null,
  description text not null,
  location_text text,
  contact_phone text,
  has_photo boolean not null default false,
  status text not null default 'received'
    check (status in ('received', 'in_progress', 'resolved', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.requests enable row level security;

create policy "Residents can create their own requests"
on public.requests for insert
to authenticated
with check (auth.uid() = resident_id);

create policy "Residents can view their own requests"
on public.requests for select
to authenticated
using (auth.uid() = resident_id);

create policy "Residents can update their own received requests"
on public.requests for update
to authenticated
using (auth.uid() = resident_id and status = 'received')
with check (auth.uid() = resident_id and status = 'received');

-- Staff access will be added later using a separate staff-role table.
