-- Safe first-pass fixes for Supabase Security Advisor function warnings.
-- This does not delete or modify business data.
--
-- Internal trigger functions should not be manually callable from API roles.
-- Triggers can still execute these functions.
revoke execute on function public.audit_row_change() from public, anon, authenticated;
revoke execute on function public.new_user_profile() from public, anon, authenticated;
revoke execute on function public.notify_task_assignment() from public, anon, authenticated;

-- These helper functions are used by row-level-security policies.
-- Do not remove authenticated access unless the RLS policies are refactored.
-- This removes broad/public access while keeping the app policies working.
revoke execute on function public.current_role() from public, anon;
revoke execute on function public.can_access_office(uuid) from public, anon;
grant execute on function public.current_role() to authenticated;
grant execute on function public.can_access_office(uuid) to authenticated;

-- Separate dashboard action:
-- Enable leaked password protection in Supabase Dashboard > Authentication > Security.
