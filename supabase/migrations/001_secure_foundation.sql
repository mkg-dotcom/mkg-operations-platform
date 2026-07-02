-- MKG secure data foundation. Review in a test project before production.
create extension if not exists pgcrypto;

create type public.app_role as enum ('admin','team_lead','employee');
create type public.task_status as enum ('pending','in_progress','waiting_for_insurance','waiting_for_office','completed','problem_claim','need_review');

create table public.offices (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text unique not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  full_name text not null,
  role public.app_role not null default 'employee',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.office_memberships (
  office_id uuid not null references public.offices(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (office_id,user_id)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  office_id uuid not null references public.offices(id) on delete restrict,
  patient_reference text not null,
  patient_name text not null,
  date_of_service date,
  task_type text not null,
  assigned_to uuid references public.profiles(id) on delete set null,
  priority text not null check (priority in ('low','medium','high','urgent')),
  status public.task_status not null default 'pending',
  due_at timestamptz,
  notes text,
  last_follow_up_at timestamptz,
  next_action_at timestamptz,
  completed_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.insurance_plans (
  id uuid primary key default gen_random_uuid(),
  office_id uuid not null references public.offices(id) on delete restrict,
  carrier text not null,
  group_name text not null,
  group_number text not null,
  template_data jsonb not null default '{}'::jsonb,
  source_file_id uuid,
  effective_from date,
  effective_to date,
  review_status text not null default 'needs_review',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (office_id,carrier,group_name,group_number)
);

create table public.verification_records (
  id uuid primary key default gen_random_uuid(),
  task_id uuid references public.tasks(id) on delete restrict,
  office_id uuid not null references public.offices(id) on delete restrict,
  insurance_plan_id uuid references public.insurance_plans(id) on delete set null,
  outcome text not null,
  verified_at timestamptz,
  verified_by uuid references public.profiles(id),
  benefit_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.claim_records (
  id uuid primary key default gen_random_uuid(),
  task_id uuid references public.tasks(id) on delete restrict,
  office_id uuid not null references public.offices(id) on delete restrict,
  claim_reference text not null,
  amount numeric(12,2) not null default 0,
  status text not null,
  submitted_at date,
  paid_at date,
  denial_code text,
  appeal_status text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.file_records (
  id uuid primary key default gen_random_uuid(),
  office_id uuid not null references public.offices(id) on delete restrict,
  bucket text not null default 'rcm-documents',
  object_path text unique not null,
  original_name text not null,
  content_type text not null,
  byte_size bigint not null check (byte_size > 0),
  sha256 text not null,
  category text not null,
  uploaded_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.insurance_plans add constraint insurance_plan_source_file_fk foreign key (source_file_id) references public.file_records(id) on delete set null;

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  office_id uuid references public.offices(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  before_data jsonb,
  after_data jsonb,
  request_id text,
  created_at timestamptz not null default now()
);

create or replace function public.current_role() returns public.app_role language sql stable security definer set search_path=public as $$ select role from public.profiles where id=auth.uid() $$;
create or replace function public.can_access_office(target uuid) returns boolean language sql stable security definer set search_path=public as $$ select public.current_role()='admin' or exists(select 1 from public.office_memberships m where m.office_id=target and m.user_id=auth.uid()) $$;

alter table public.offices enable row level security;
alter table public.profiles enable row level security;
alter table public.office_memberships enable row level security;
alter table public.tasks enable row level security;
alter table public.insurance_plans enable row level security;
alter table public.verification_records enable row level security;
alter table public.claim_records enable row level security;
alter table public.file_records enable row level security;
alter table public.audit_events enable row level security;

create policy offices_read on public.offices for select to authenticated using (public.can_access_office(id));
create policy profiles_self_or_lead_read on public.profiles for select to authenticated using (id=auth.uid() or public.current_role() in ('admin','team_lead'));
create policy memberships_read on public.office_memberships for select to authenticated using (user_id=auth.uid() or public.current_role() in ('admin','team_lead'));
create policy tasks_read on public.tasks for select to authenticated using (public.can_access_office(office_id) and (public.current_role() in ('admin','team_lead') or assigned_to=auth.uid()));
create policy tasks_create on public.tasks for insert to authenticated with check (public.current_role() in ('admin','team_lead') and public.can_access_office(office_id) and created_by=auth.uid());
create policy tasks_update on public.tasks for update to authenticated using (public.can_access_office(office_id) and (public.current_role() in ('admin','team_lead') or assigned_to=auth.uid())) with check (public.can_access_office(office_id));
create policy plans_read on public.insurance_plans for select to authenticated using (public.can_access_office(office_id));
create policy plans_write on public.insurance_plans for all to authenticated using (public.current_role() in ('admin','team_lead') and public.can_access_office(office_id)) with check (public.current_role() in ('admin','team_lead') and public.can_access_office(office_id));
create policy verifications_read on public.verification_records for select to authenticated using (public.can_access_office(office_id));
create policy verifications_write on public.verification_records for insert to authenticated with check (public.can_access_office(office_id) and verified_by=auth.uid());
create policy claims_read on public.claim_records for select to authenticated using (public.can_access_office(office_id));
create policy claims_write on public.claim_records for all to authenticated using (public.can_access_office(office_id)) with check (public.can_access_office(office_id));
create policy files_read on public.file_records for select to authenticated using (public.can_access_office(office_id));
create policy files_insert on public.file_records for insert to authenticated with check (public.can_access_office(office_id) and uploaded_by=auth.uid());
create policy audit_admin_read on public.audit_events for select to authenticated using (public.current_role()='admin' or (public.current_role()='team_lead' and public.can_access_office(office_id)));

revoke update, delete on public.audit_events from authenticated;

create or replace function public.audit_row_change() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.audit_events(actor_id,office_id,action,entity_type,entity_id,before_data,after_data)
  values(auth.uid(),coalesce((to_jsonb(new)->>'office_id')::uuid,(to_jsonb(old)->>'office_id')::uuid),tg_op,tg_table_name,coalesce(to_jsonb(new)->>'id',to_jsonb(old)->>'id'),case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end);
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;

create trigger tasks_audit after insert or update or delete on public.tasks for each row execute function public.audit_row_change();
create trigger plans_audit after insert or update or delete on public.insurance_plans for each row execute function public.audit_row_change();
create trigger claims_audit after insert or update or delete on public.claim_records for each row execute function public.audit_row_change();
create trigger files_audit after insert or update or delete on public.file_records for each row execute function public.audit_row_change();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('rcm-documents','rcm-documents',false,15728640,array['application/pdf','text/csv','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
on conflict (id) do nothing;

-- Storage uploads are restricted to a user-owned staging prefix. A trusted server function
-- must validate the office/task and move the object to its final path before creating file_records.
create policy storage_user_staging_insert on storage.objects for insert to authenticated
with check (bucket_id='rcm-documents' and (storage.foldername(name))[1]='staging' and (storage.foldername(name))[2]=auth.uid()::text);
