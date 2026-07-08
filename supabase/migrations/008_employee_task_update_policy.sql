-- Allow employees to update task rows they created, are assigned to,
-- or are allowed to work on through office membership.
-- This fixes shared-save failures like:
-- "new row violates row-level security policy (USING expression) for table tasks"

drop policy if exists tasks_update on public.tasks;

create policy tasks_update
on public.tasks
for update
to authenticated
using (
  public.current_role() in ('admin','team_lead')
  or assigned_to = auth.uid()
  or created_by = auth.uid()
  or public.can_access_office(office_id)
)
with check (
  public.current_role() in ('admin','team_lead')
  or assigned_to = auth.uid()
  or created_by = auth.uid()
  or public.can_access_office(office_id)
);

grant update on public.tasks to authenticated;
