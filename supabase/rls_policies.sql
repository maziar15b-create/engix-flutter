create policy "members_update_own_prefs_or_admin"
  on conversation_members for update
  using (
    user_id = auth.uid()
    or conversation_member_role(conversation_id, auth.uid()) in ('owner', 'admin')
  )
  with check (
    user_id = auth.uid()
    or conversation_member_role(conversation_id, auth.uid()) in ('owner', 'admin')
  );

-- Leave yourself, or be removed by owner/admin
drop policy if exists "members_delete_self_or_admin" on conversation_members;
create policy "members_delete_self_or_admin"
  on conversation_members for delete
  using (
    user_id = auth.uid()
    or conversation_member_role(conversation_id, auth.uid()) in ('owner', 'admin')
  );

-- ============================================================
-- messages
-- ============================================================
alter table messages enable row level security;

drop policy if exists "messages_select_if_member" on messages;
create policy "messages_select_if_member"
  on messages for select
  using (is_conversation_member(conversation_id, auth.uid()));

drop policy if exists "messages_insert_if_member_not_blocked" on messages;
create policy "messages_insert_if_member_not_blocked"
  on messages for insert
  with check (
    sender_id = auth.uid()
    and is_conversation_member(conversation_id, auth.uid())
    and not exists (
      -- block sending in a direct conversation if either side blocked the other
      select 1 from conversation_members cm
      where cm.conversation_id = messages.conversation_id
        and cm.user_id <> auth.uid()
        and users_blocked_each_other(auth.uid(), cm.user_id)
    )
  );

drop policy if exists "messages_update_own" on messages;
create policy "messages_update_own"
  on messages for update
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

-- ============================================================
-- message_reads
-- ============================================================
alter table message_reads enable row level security;

drop policy if exists "reads_select_if_conversation_member" on message_reads;
create policy "reads_select_if_conversation_member"
  on message_reads for select
  using (
    exists (
      select 1 from messages m
      where m.id = message_reads.message_id
        and is_conversation_member(m.conversation_id, auth.uid())
    )
  );

drop policy if exists "reads_insert_own" on message_reads;
create policy "reads_insert_own"
  on message_reads for insert
  with check (user_id = auth.uid());

drop policy if exists "reads_update_own" on message_reads;
create policy "reads_update_own"
  on message_reads for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================
-- typing_status (optional persisted table — safe to keep even
-- though live typing uses Realtime broadcast, not DB rows)
-- ============================================================
alter table typing_status enable row level security;

drop policy if exists "typing_select_if_member" on typing_status;
create policy "typing_select_if_member"
  on typing_status for select
  using (is_conversation_member(conversation_id, auth.uid()));

drop policy if exists "typing_upsert_own" on typing_status;
create policy "typing_upsert_own"
  on typing_status for insert
  with check (user_id = auth.uid());

drop policy if exists "typing_update_own" on typing_status;
create policy "typing_update_own"
  on typing_status for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================
-- contacts
-- ============================================================
alter table contacts enable row level security;

drop policy if exists "contacts_select_own" on contacts;
create policy "contacts_select_own"
  on contacts for select
  using (owner_id = auth.uid());

drop policy if exists "contacts_insert_own" on contacts;
create policy "contacts_insert_own"
  on contacts for insert
  with check (owner_id = auth.uid());drop policy if exists "contacts_delete_own" on contacts;
create policy "contacts_delete_own"
  on contacts for delete
  using (owner_id = auth.uid());

-- ============================================================
-- blocks
-- ============================================================
alter table blocks enable row level security;

drop policy if exists "blocks_select_own" on blocks;
create policy "blocks_select_own"
  on blocks for select
  using (blocker_id = auth.uid());

drop policy if exists "blocks_insert_own" on blocks;
create policy "blocks_insert_own"
  on blocks for insert
  with check (blocker_id = auth.uid());

drop policy if exists "blocks_delete_own" on blocks;
create policy "blocks_delete_own"
  on blocks for delete
  using (blocker_id = auth.uid());

-- ============================================================
-- reports
-- ============================================================
alter table reports enable row level security;

drop policy if exists "reports_insert_own" on reports;
create policy "reports_insert_own"
  on reports for insert
  with check (reporter_id = auth.uid());

-- Only the reporter can see their own submitted reports
-- (admins reviewing reports would use a service-role key, bypassing RLS)
drop policy if exists "reports_select_own" on reports;
create policy "reports_select_own"
  on reports for select
  using (reporter_id = auth.uid());

-- ============================================================
-- Storage bucket policy (messenger-attachments)
-- Run separately if the bucket already exists via Dashboard, or here:
-- ============================================================

-- Members of a conversation can read/write files under a path that
-- starts with that conversation's id (see lib/upload.js storagePath).
drop policy if exists "attachments_select_if_member" on storage.objects;
create policy "attachments_select_if_member"
  on storage.objects for select
  using (
    bucket_id = 'messenger-attachments'
    and is_conversation_member(split_part(name, '/', 1), auth.uid())
  );

drop policy if exists "attachments_insert_if_member" on storage.objects;
create policy "attachments_insert_if_member"
  on storage.objects for insert
  with check (
    bucket_id = 'messenger-attachments'
    and is_conversation_member(split_part(name, '/', 1), auth.uid())
  );

drop policy if exists "attachments_delete_if_member" on storage.objects;
create policy "attachments_delete_if_member"
  on storage.objects for delete
  using (
    bucket_id = 'messenger-attachments'
    and is_conversation_member(split_part(name, '/', 1), auth.uid())
  );drop policy if exists "contacts_delete_own" on contacts;
create policy "contacts_delete_own"
  on contacts for delete
  using (owner_id = auth.uid());

-- ============================================================
-- blocks
-- ============================================================
alter table blocks enable row level security;

drop policy if exists "blocks_select_own" on blocks;
create policy "blocks_select_own"
  on blocks for select
  using (blocker_id = auth.uid());

drop policy if exists "blocks_insert_own" on blocks;
create policy "blocks_insert_own"
  on blocks for insert
  with check (blocker_id = auth.uid());

drop policy if exists "blocks_delete_own" on blocks;
create policy "blocks_delete_own"
  on blocks for delete
  using (blocker_id = auth.uid());

-- ============================================================
-- reports
-- ============================================================
alter table reports enable row level security;

drop policy if exists "reports_insert_own" on reports;
create policy "reports_insert_own"
  on reports for insert
  with check (reporter_id = auth.uid());

-- Only the reporter can see their own submitted reports
-- (admins reviewing reports would use a service-role key, bypassing RLS)
drop policy if exists "reports_select_own" on reports;
create policy "reports_select_own"
  on reports for select
  using (reporter_id = auth.uid());

-- ============================================================
-- Storage bucket policy (messenger-attachments)
-- Run separately if the bucket already exists via Dashboard, or here:
-- ============================================================

-- Members of a conversation can read/write files under a path that
-- starts with that conversation's id (see lib/upload.js storagePath).
drop policy if exists "attachments_select_if_member" on storage.objects;
create policy "attachments_select_if_member"
  on storage.objects for select
  using (
    bucket_id = 'messenger-attachments'
    and is_conversation_member(split_part(name, '/', 1), auth.uid())
  );

drop policy if exists "attachments_insert_if_member" on storage.objects;
create policy "attachments_insert_if_member"
  on storage.objects for insert
  with check (
    bucket_id = 'messenger-attachments'
    and is_conversation_member(split_part(name, '/', 1), auth.uid())
  );

drop policy if exists "attachments_delete_if_member" on storage.objects;
create policy "attachments_delete_if_member"
  on storage.objects for delete
  using (
    bucket_id = 'messenger-attachments'
    and is_conversation_member(split_part(name, '/', 1), auth.uid())
  );
