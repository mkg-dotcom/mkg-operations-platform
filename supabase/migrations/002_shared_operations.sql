-- Shared multi-user operations, role profiles, EOD reports, and notifications.
alter table public.profiles add column if not exists position text not null default 'Team Member';
alter table public.profiles add column if not exists email text;

insert into public.offices(name,code) values
('Bright Smile Dental','BSD'),('Oakwood Family Dentistry','OFD'),('Lakeside Dental Care','LDC'),('Sunrise Pediatric Dental','SPD')
on conflict(code) do nothing;

alter table public.tasks alter column status drop default;
alter table public.tasks alter column status type text using status::text;
alter table public.tasks alter column status set default 'Pending';
alter table public.tasks add column if not exists external_id text unique;
alter table public.tasks add column if not exists posted_amount numeric(12,2);
alter table public.tasks add column if not exists posted_date date;
alter table public.tasks add column if not exists qa_status text not null default 'Pending review';
alter table public.tasks add column if not exists qa_score numeric(5,2) check (qa_score between 0 and 100);
alter table public.tasks add column if not exists qa_notes text;
alter table public.tasks add column if not exists qa_reviewer uuid references public.profiles(id) on delete set null;

create table if not exists public.eod_reports (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete restrict,
  office_id uuid references public.offices(id) on delete set null,
  report_date date not null default current_date,
  tasks_completed integer not null default 0,
  pending_items text,
  problem_claims text,
  notes text,
  time_worked text,
  review_status text not null default 'Pending review',
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(employee_id,report_date,office_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_id uuid references public.tasks(id) on delete cascade,
  kind text not null,
  title text not null,
  message text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.eod_reports enable row level security;
alter table public.notifications enable row level security;

create policy profiles_admin_update on public.profiles for update to authenticated
using (public.current_role()='admin') with check (public.current_role()='admin');
create policy offices_admin_write on public.offices for all to authenticated
using (public.current_role()='admin') with check (public.current_role()='admin');
create policy memberships_admin_write on public.office_memberships for all to authenticated
using (public.current_role()='admin') with check (public.current_role()='admin');
create policy eod_read on public.eod_reports for select to authenticated
using (employee_id=auth.uid() or public.current_role() in ('admin','team_lead'));
create policy eod_insert on public.eod_reports for insert to authenticated
with check (employee_id=auth.uid() or public.current_role() in ('admin','team_lead'));
create policy eod_lead_update on public.eod_reports for update to authenticated
using (public.current_role() in ('admin','team_lead')) with check (public.current_role() in ('admin','team_lead'));
create policy notifications_read on public.notifications for select to authenticated using (user_id=auth.uid());
create policy notifications_update on public.notifications for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

create or replace function public.new_user_profile() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,full_name,email,role,position,active)
  values(new.id,coalesce(new.raw_user_meta_data->>'full_name',split_part(new.email,'@',1)),new.email,'employee','Team Member',true)
  on conflict(id) do nothing;
  return new;
end $$;
drop trigger if exists auth_user_profile on auth.users;
create trigger auth_user_profile after insert on auth.users for each row execute function public.new_user_profile();

create or replace function public.notify_task_assignment() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.assigned_to is not null and (tg_op='INSERT' or old.assigned_to is distinct from new.assigned_to) then
    insert into public.office_memberships(office_id,user_id) values(new.office_id,new.assigned_to) on conflict do nothing;
    insert into public.notifications(user_id,task_id,kind,title,message)
    values(new.assigned_to,new.id,'assignment','New task assigned',new.task_type||': '||new.patient_name);
  end if;
  return new;
end $$;
drop trigger if exists task_assignment_notification on public.tasks;
create trigger task_assignment_notification after insert or update of assigned_to on public.tasks for each row execute function public.notify_task_assignment();

-- Permit role-appropriate inserts/updates after the status column becomes extensible text.
grant select,insert,update on public.eod_reports to authenticated;
grant select,update on public.notifications to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.tasks;
exception when duplicate_object then null;
end $$;
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null;
end $$;
