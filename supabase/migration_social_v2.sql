-- ============================================================
-- EngiX — تکمیل شبکه اجتماعی (عکس پست، ویرایش پست/کامنت)
-- این migration را بعد از migration_social.sql اجرا کنید
-- ============================================================

alter table posts add column if not exists image_url text;
alter table posts add column if not exists updated_at timestamptz not null default now();

alter table post_comments add column if not exists updated_at timestamptz not null default now();

-- ============================================================
-- سیاست‌های ویرایش (قبلاً فقط select/insert/delete داشتیم)
-- ============================================================
drop policy if exists "posts_update_own" on posts;
create policy "posts_update_own" on posts for update using (author_id = auth.uid()) with check (author_id = auth.uid());

drop policy if exists "post_comments_update_own" on post_comments;
create policy "post_comments_update_own" on post_comments for update using (author_id = auth.uid()) with check (author_id = auth.uid());

-- ============================================================
-- Storage bucket برای عکس پست‌ها
-- ============================================================
insert into storage.buckets (id, name, public)
values ('post-images', 'post-images', true)
on conflict (id) do nothing;

drop policy if exists "post_images_select_all" on storage.objects;
create policy "post_images_select_all" on storage.objects
  for select using (bucket_id = 'post-images');

drop policy if exists "post_images_insert_own" on storage.objects;
create policy "post_images_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "post_images_delete_own" on storage.objects;
create policy "post_images_delete_own" on storage.objects
  for delete using (
    bucket_id = 'post-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
