-- ============================================================
-- EngiX — سیستم اخبار خودکار
-- ============================================================
create table if not exists news_categories (
  id uuid primary key default gen_random_uuid(),
  key text unique not null,
  label text not null,
  sort_order int not null default 0
);

insert into news_categories (key, label, sort_order) values
  ('nezam',        'اخبار نظام مهندسی',      0),
  ('exams',        'آزمون‌ها',                1),
  ('insurance',    'بیمه',                    2),
  ('regulations',  'قوانین و آیین‌نامه‌ها',   3),
  ('materials',    'قیمت مصالح',              4),
  ('civil',        'پروژه‌های عمرانی',        5),
  ('education',    'آموزش',                   6),
  ('announcements','اطلاعیه‌ها',              7)
on conflict (key) do nothing;

create table if not exists news_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  rss_url text unique not null,
  default_category_key text not null default 'civil' references news_categories(key),
  is_active boolean not null default true,
  last_fetched_at timestamptz,
  created_at timestamptz not null default now()
);

insert into news_sources (name, rss_url, default_category_key) values
  ('ایسنا', 'https://www.isna.ir/rss', 'civil'),
  ('مهر نیوز', 'https://www.mehrnews.com/rss', 'civil')
on conflict (rss_url) do nothing;

create table if not exists news (
  id uuid primary key default gen_random_uuid(),
  source_id uuid references news_sources(id) on delete set null,
  category_id uuid references news_categories(id) on delete set null,
  title text not null,
  summary text,
  keywords text[] default '{}',
  importance smallint not null default 1 check (importance between 1 and 5),
  url text unique not null,
  image_url text,
  published_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_news_created on news(created_at desc);
create index if not exists idx_news_category on news(category_id);
create index if not exists idx_news_importance on news(importance);

alter table profiles add column if not exists news_seen_at timestamptz default now();

alter table news_categories enable row level security;
drop policy if exists "news_categories_select_all" on news_categories;
create policy "news_categories_select_all" on news_categories for select using (true);

alter table news_sources enable row level security;
drop policy if exists "news_sources_select_all" on news_sources;
create policy "news_sources_select_all" on news_sources for select using (true);

alter table news enable row level security;
drop policy if exists "news_select_all" on news;
create policy "news_select_all" on news for select using (true);
