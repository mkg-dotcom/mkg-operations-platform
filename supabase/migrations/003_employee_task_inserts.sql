-- Allow employees to add their own operational rows, such as verification,
-- calls, payment posting, pre-auth, and claim status updates.
-- They may only create tasks for offices they can access, and the task must
-- be assigned to themselves. Admins/team leads keep their broader create policy.

drop policy if exists tasks_employee_create_own on public.tasks;

create policy tasks_employee_create_own
on public.tasks
for insert
to authenticated
with check (
  public.current_role() = 'employee'
  and public.can_access_office(office_id)
  and created_by = auth.uid()
  and assigned_to = auth.uid()
);
