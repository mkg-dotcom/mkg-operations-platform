-- Shared company-wide Admin Settings for MKG module workflows.
-- Run this once in Supabase SQL Editor.

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

alter table public.app_settings enable row level security;

drop policy if exists app_settings_read_authenticated on public.app_settings;
create policy app_settings_read_authenticated
on public.app_settings
for select
to authenticated
using (true);

drop policy if exists app_settings_admin_insert on public.app_settings;
create policy app_settings_admin_insert
on public.app_settings
for insert
to authenticated
with check (public.current_role() = 'admin');

drop policy if exists app_settings_admin_update on public.app_settings;
create policy app_settings_admin_update
on public.app_settings
for update
to authenticated
using (public.current_role() = 'admin')
with check (public.current_role() = 'admin');

grant select, insert, update on public.app_settings to authenticated;
