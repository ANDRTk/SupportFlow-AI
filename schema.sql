-- SupportFlow AI: minimal reference schema for recreating the portfolio demo.
-- Reconstructed from the exported n8n REST requests, NOT an original DB migration.
-- Execute in Supabase SQL Editor. Adjust to suit an existing schema if needed.

create extension if not exists vector;

create table if not exists public.chat_messages (
  id bigint generated always as identity primary key,
  chat_id bigint not null,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  telegram_update_id bigint,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_chat_time_idx
  on public.chat_messages (chat_id, created_at desc, id desc);

create table if not exists public.knowledge_chunks (
  id bigint generated always as identity primary key,
  source_id text not null unique,
  title text not null,
  content text not null,
  chunk_index integer not null,
  embedding vector(768) not null,
  created_at timestamptz not null default now()
);

create or replace function public.match_knowledge_chunks(
  query_embedding vector(768),
  match_count integer default 3
)
returns table (
  source_id text,
  title text,
  content text,
  similarity double precision
)
language sql
stable
as $$
  select
    k.source_id,
    k.title,
    k.content,
    1.0 - (k.embedding <=> query_embedding) as similarity
  from public.knowledge_chunks as k
  order by k.embedding <=> query_embedding
  limit greatest(match_count, 0);
$$;

create table if not exists public.support_tickets (
  id bigint generated always as identity primary key,
  chat_id bigint not null,
  trello_card_id text not null unique,
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

create unique index if not exists support_tickets_one_open_per_chat_idx
  on public.support_tickets (chat_id)
  where status = 'open';

create table if not exists public.trello_reply_events (
  action_id text primary key,
  trello_card_id text not null,
  chat_id bigint not null,
  status text not null default 'pending' check (status in ('pending', 'sent')),
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  telegram_message_id bigint
);

-- The workflows use privileged, server-side Supabase credentials from n8n.
-- Enable RLS to keep the tables private from normal anonymous API clients.
-- The service_role bypasses RLS; NEVER expose its key on the web or in GitHub.
alter table public.chat_messages enable row level security;
alter table public.knowledge_chunks enable row level security;
alter table public.support_tickets enable row level security;
alter table public.trello_reply_events enable row level security;
