-- ============================================================
-- EngiX Messenger — Table creation
-- Run this BEFORE rls_policies.sql
-- Assumes profiles table already exists (linked to auth.users)
-- with at least: id (uuid, references auth.users), code, name,
-- phone, avatar_url, is_online, last_seen
-- ============================================================

-- If your profiles table doesn't yet have these messenger-related
-- columns, add them:
alter table profiles add column if not exists is_online boolean default false;
alter table profiles add column if not exists last_seen timestamptz;
alter table profiles add column if not exists phone text;
alter table profiles add column if not exists avatar_url text;

-- ------------------------------------------------------------
-- conversations
-- ------------------------------------------------------------
create table if not exists conversations (
  id text primary key,
  type text not null check (type in ('direct', 'group', 'channel')),
  name text,
  avatar_url text,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- conversation_members
-- ------------------------------------------------------------
create table if not exists conversation_members (
  conversation_id text not null references conversations(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member')),
  is_muted boolean not null default false,
  is_pinned boolean not null default false,
  is_archived boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create index if not exists idx_members_user on conversation_members(user_id);
create index if not exists idx_members_conversation on conversation_members(conversation_id);

-- ------------------------------------------------------------
-- messages
-- ------------------------------------------------------------
create table if not exists messages (
  id text primary key,
  conversation_id text not null references conversations(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  type text not null default 'text' check (type in ('text', 'image', 'pdf', 'word', 'voice')),
  content text,
  file_url text,
  file_meta jsonb,
  reply_to text references messages(id) on delete set null,
  forwarded_from uuid references profiles(id) on delete set null,
  is_edited boolean not null default false,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_messages_conversation_created on messages(conversation_id, created_at desc);
create index if not exists idx_messages_sender on messages(sender_id);

-- ------------------------------------------------------------
-- message_reads
-- ------------------------------------------------------------
create table if not exists message_reads (
  message_id text not null references messages(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

-- ------------------------------------------------------------
-- typing_status (optional persisted fallback; live typing uses
-- Realtime broadcast in lib/realtime.js, not this table — kept
-- for potential future use, e.g. showing typing after reconnect)
-- ------------------------------------------------------------
create table if not exists typing_status (
  conversation_id text not null references conversations(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  updated_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);-- ------------------------------------------------------------
-- contacts
-- ------------------------------------------------------------
create table if not exists contacts (
  owner_id uuid not null references profiles(id) on delete cascade,
  contact_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, contact_id)
);

-- ------------------------------------------------------------
-- blocks
-- ------------------------------------------------------------
create table if not exists blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

-- ------------------------------------------------------------
-- reports
-- ------------------------------------------------------------
create table if not exists reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id) on delete cascade,
  target_user_id uuid not null references profiles(id) on delete cascade,
  reason text,
  context jsonb,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Enable Realtime replication (equivalent of the Dashboard toggle)
-- ------------------------------------------------------------
alter publication supabase_realtime add table conversations;
alter publication supabase_realtime add table conversation_members;
alter publication supabase_realtime add table messages;
