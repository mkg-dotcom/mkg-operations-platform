-- Private Supabase Storage bucket for claim/EOB attachments.
-- Run this once in Supabase SQL Editor.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'claim-attachments',
  'claim-attachments',
  false,
  10485760,
  array['application/pdf','image/jpeg','image/png']::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = 10485760,
    allowed_mime_types = array['application/pdf','image/jpeg','image/png']::text[];

drop policy if exists claim_attachments_read_authenticated on storage.objects;
create policy claim_attachments_read_authenticated
on storage.objects
for select
to authenticated
using (bucket_id = 'claim-attachments');

drop policy if exists claim_attachments_upload_authenticated on storage.objects;
create policy claim_attachments_upload_authenticated
on storage.objects
for insert
to authenticated
with check (bucket_id = 'claim-attachments');
