-- Allow admins to delete duplicate or incorrect task rows from the app.
-- This does not delete anything by itself; it only permits admin-initiated deletes.

drop policy if exists tasks_admin_delete on public.tasks;

create policy tasks_admin_delete
on public.tasks
for delete
to authenticated
using (public.current_role() = 'admin');

grant delete on public.tasks to authenticated;
