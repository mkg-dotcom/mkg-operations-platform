-- Keep MKG task visibility and syncing consistent across Admin, Team Lead, and Employee views.
-- Admins can see/manage all tasks. Team leads can manage office/member tasks.
-- Employees can see and update tasks assigned to them, created by them, or in offices they can access.

drop policy if exists tasks_read on public.tasks;
drop policy if exists tasks_create on public.tasks;
drop policy if exists tasks_employee_create_own on public.tasks;
drop policy if exists tasks_update on public.tasks;
drop policy if exists tasks_admin_delete on public.tasks;

create policy tasks_read
on public.tasks
for select
to authenticated
using (
  public.current_role() = 'admin'
  or (
    public.current_role() = 'team_lead'
    and public.can_access_office(office_id)
  )
  or assigned_to = auth.uid()
  or created_by = auth.uid()
  or public.can_access_office(office_id)
);

create policy tasks_create
on public.tasks
for insert
to authenticated
with check (
  created_by = auth.uid()
  and (
    public.current_role() = 'admin'
    or (
      public.current_role() = 'team_lead'
      and public.can_access_office(office_id)
    )
    or (
      public.current_role() = 'employee'
      and public.can_access_office(office_id)
      and (assigned_to = auth.uid() or assigned_to is null)
    )
  )
);

create policy tasks_update
on public.tasks
for update
to authenticated
using (
  public.current_role() = 'admin'
  or (
    public.current_role() = 'team_lead'
    and public.can_access_office(office_id)
  )
  or assigned_to = auth.uid()
  or created_by = auth.uid()
  or public.can_access_office(office_id)
)
with check (
  public.current_role() = 'admin'
  or (
    public.current_role() = 'team_lead'
    and public.can_access_office(office_id)
  )
  or assigned_to = auth.uid()
  or created_by = auth.uid()
  or public.can_access_office(office_id)
);

create policy tasks_admin_delete
on public.tasks
for delete
to authenticated
using (public.current_role() = 'admin');

grant select, insert, update, delete on public.tasks to authenticated;
