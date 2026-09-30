-- ============================================================
-- EngiX — رفع مشکل «باکت‌های گم‌شده»
-- کد پروژه به این ۴ باکت آپلود می‌کند ولی هیچ‌کدام در migration های
-- قبلی ساخته نشده بودند (فقط ad-images و post-images ساخته شده بودند):
--   avatars, wallpapers, project-media, messenger-attachments
-- نتیجه: یا آپلود اصلاً fail می‌شود، یا اگر باکت را دستی از داشبورد
-- ساخته باشید بدون public/policy درست، لینک عکس ۴۰۳ برمی‌گرداند.
--
-- این فایل idempotent است و اجرای دوباره‌اش مشکلی ایجاد نمی‌کند.
-- ============================================================

-- ------------------------------------------------------------
-- avatars — آواتار کاربر (profile.id/avatar.ext) و آواتار گروه/کانال
-- (conversations/{conversationId}/avatar.ext)
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars_select_all" on storage.objects;
create policy "avatars_select_all" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatars_write_own" on storage.objects;
create policy "avatars_write_own" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and (
      split_part(name, '/', 1) = auth.uid()::text
      or (
        split_part(name, '/', 1) = 'conversations'
        and is_conversation_member(split_part(name, '/', 2), auth.uid())
      )
    )
  );

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own" on storage.objects
  for update using (
    bucket_id = 'avatars'
    and (
      split_part(name, '/', 1) = auth.uid()::text
      or (
        split_part(name, '/', 1) = 'conversations'
        and is_conversation_member(split_part(name, '/', 2), auth.uid())
      )
    )
  );

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own" on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and (
      split_part(name, '/', 1) = auth.uid()::text
      or (
        split_part(name, '/', 1) = 'conversations'
        and is_conversation_member(split_part(name, '/', 2), auth.uid())
      )
    )
  );

-- ------------------------------------------------------------
-- wallpapers — پس‌زمینه‌ی چت (profile.id/wallpaper-*.ext)
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('wallpapers', 'wallpapers', true)
on conflict (id) do nothing;

drop policy if exists "wallpapers_select_all" on storage.objects;
create policy "wallpapers_select_all" on storage.objects
  for select using (bucket_id = 'wallpapers');

drop policy if exists "wallpapers_write_own" on storage.objects;
create policy "wallpapers_write_own" on storage.objects
  for insert with check (
    bucket_id = 'wallpapers' and split_part(name, '/', 1) = auth.uid()::text
  );

drop policy if exists "wallpapers_update_own" on storage.objects;
create policy "wallpapers_update_own" on storage.objects
  for update using (
    bucket_id = 'wallpapers' and split_part(name, '/', 1) = auth.uid()::text
  );

drop policy if exists "wallpapers_delete_own" on storage.objects;
create policy "wallpapers_delete_own" on storage.objects
  for delete using (
    bucket_id = 'wallpapers' and split_part(name, '/', 1) = auth.uid()::text
  );

-- ------------------------------------------------------------
-- project-media — عکس/ویدیو/صدای پروژه (projectId/timestamp-rand.ext)
-- توجه: چون جدول عضویت پروژه‌ها (project_members یا مشابه) در
-- migration های ردیابی‌شده‌ی این ریپازیتوری تعریف نشده، فعلاً فقط
-- «ورود با حساب کاربری» شرط insert است، نه «عضو همین پروژه بودن».
-- اگر جدول عضویت پروژه دارید، این پالیسی insert را با شرط عضویت
-- سفت‌تر کنید.
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('project-media', 'project-media', true)
on conflict (id) do nothing;

drop policy if exists "project_media_select_all" on storage.objects;
create policy "project_media_select_all" on storage.objects
  for select using (bucket_id = 'project-media');

drop policy if exists "project_media_insert_authenticated" on storage.objects;
create policy "project_media_insert_authenticated" on storage.objects
  for insert with check (
    bucket_id = 'project-media' and auth.uid() is not null
  );

drop policy if exists "project_media_delete_authenticated" on storage.objects;
create policy "project_media_delete_authenticated" on storage.objects
  for delete using (
    bucket_id = 'project-media' and auth.uid() is not null
  );

-- ------------------------------------------------------------
-- messenger-attachments — پیوست پیام‌رسان
-- خودِ باکت اینجا ساخته می‌شود؛ پالیسی‌های select/insert/delete
-- از قبل در rls_policies.sql تعریف شده‌اند (بر پایه‌ی
-- is_conversation_member) و همچنان معتبرند.
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('messenger-attachments', 'messenger-attachments', true)
on conflict (id) do nothing;
