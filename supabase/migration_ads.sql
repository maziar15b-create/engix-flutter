-- ============================================================
-- EngiX — فیچر تبلیغات هدفمند (بخش خانه)
-- ============================================================

create table if not exists ads (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text,
  image_url text,
  target_url text,
  button_text text not null default 'مشاهده',
  target_roles text[] default null, -- null یا آرایه خالی یعنی نمایش به همه
  start_at timestamptz not null default now(),
  end_at timestamptz,
  active boolean not null default true,
  priority integer not null default 0,
  impression_count bigint not null default 0,
  click_count bigint not null default 0,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table ads enable row level security;

drop policy if exists "ads_select_active" on ads;
create policy "ads_select_active" on ads
  for select using (
    active = true
    and start_at <= now()
    and (end_at is null or end_at >= now())
  );

drop policy if exists "ads_admin_all" on ads;
create policy "ads_admin_all" on ads
  for all using (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
  ) with check (
    exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
  );

create or replace function public.increment_ad_stat(ad_id uuid, stat text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if stat = 'impression' then
    update ads set impression_count = impression_count + 1 where id = ad_id;
  elsif stat = 'click' then
    update ads set click_count = click_count + 1 where id = ad_id;
  end if;
end;
$$;

grant execute on function public.increment_ad_stat(uuid, text) to anon, authenticated;

insert into storage.buckets (id, name, public)
values ('ad-images', 'ad-images', true)
on conflict (id) do nothing;

drop policy if exists "ad_images_select_all" on storage.objects;
create policy "ad_images_select_all" on storage.objects
  for select using (bucket_id = 'ad-images');

drop policy if exists "ad_images_admin_write" on storage.objects;
create policy "ad_images_admin_write" on storage.objects
  for insert with check (
    bucket_id = 'ad-images'
    and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
  );

drop policy if exists "ad_images_admin_delete" on storage.objects;
create policy "ad_images_admin_delete" on storage.objects
  for delete using (
    bucket_id = 'ad-images'
    and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
  );
