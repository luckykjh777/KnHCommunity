-- KnHCommunity Supabase schema
-- Supabase Dashboard > SQL Editor에서 한 번 실행하세요.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null unique check (char_length(nickname) between 2 and 16),
  bio text not null default '' check (char_length(bio) <= 300),
  created_at timestamptz not null default now()
);

create table if not exists public.wiki_pages (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 120),
  slug text not null unique,
  content text not null check (char_length(content) between 2 and 50000),
  author_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists wiki_pages_updated_idx on public.wiki_pages(updated_at desc);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 120),
  body text not null check (char_length(body) between 2 and 30000),
  author_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists posts_created_idx on public.posts(created_at desc);

create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 3000),
  created_at timestamptz not null default now()
);
create index if not exists post_comments_post_idx on public.post_comments(post_id,created_at);

create table if not exists public.discussion_messages (
  id uuid primary key default gen_random_uuid(),
  channel text not null check (channel in ('general','wiki','free-talk','help')),
  body text not null check (char_length(body) between 1 and 5000),
  author_id uuid not null references public.profiles(id) on delete cascade,
  reply_to uuid references public.discussion_messages(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists discussion_messages_channel_idx on public.discussion_messages(channel,created_at);

create table if not exists public.discussion_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.discussion_messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null check (emoji in ('👍','❤️','😂','🎉','👀')),
  created_at timestamptz not null default now(),
  unique(message_id,user_id,emoji)
);

-- Create a profile automatically after signup. Nickname collision is reported to signup client.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare chosen text;
begin
  chosen := coalesce(nullif(new.raw_user_meta_data->>'nickname',''), split_part(new.email,'@',1));
  insert into public.profiles(id,nickname) values(new.id,chosen);
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- RLS: public can read community content; signed-in users create content as themselves.
alter table public.profiles enable row level security;
alter table public.wiki_pages enable row level security;
alter table public.posts enable row level security;
alter table public.post_comments enable row level security;
alter table public.discussion_messages enable row level security;
alter table public.discussion_reactions enable row level security;

drop policy if exists "profiles public read" on public.profiles;
create policy "profiles public read" on public.profiles for select using (true);
drop policy if exists "profile owner update" on public.profiles;
create policy "profile owner update" on public.profiles for update to authenticated using (auth.uid()=id) with check (auth.uid()=id);

drop policy if exists "wiki public read" on public.wiki_pages;
create policy "wiki public read" on public.wiki_pages for select using (true);
drop policy if exists "wiki authenticated insert" on public.wiki_pages;
create policy "wiki authenticated insert" on public.wiki_pages for insert to authenticated with check (auth.uid()=author_id);
drop policy if exists "wiki author update" on public.wiki_pages;
create policy "wiki author update" on public.wiki_pages for update to authenticated using (auth.uid()=author_id) with check (auth.uid()=author_id);
drop policy if exists "wiki author delete" on public.wiki_pages;
create policy "wiki author delete" on public.wiki_pages for delete to authenticated using (auth.uid()=author_id);

drop policy if exists "posts public read" on public.posts;
create policy "posts public read" on public.posts for select using (true);
drop policy if exists "posts authenticated insert" on public.posts;
create policy "posts authenticated insert" on public.posts for insert to authenticated with check (auth.uid()=author_id);
drop policy if exists "posts author update" on public.posts;
create policy "posts author update" on public.posts for update to authenticated using (auth.uid()=author_id) with check (auth.uid()=author_id);
drop policy if exists "posts author delete" on public.posts;
create policy "posts author delete" on public.posts for delete to authenticated using (auth.uid()=author_id);

drop policy if exists "comments public read" on public.post_comments;
create policy "comments public read" on public.post_comments for select using (true);
drop policy if exists "comments authenticated insert" on public.post_comments;
create policy "comments authenticated insert" on public.post_comments for insert to authenticated with check (auth.uid()=author_id);
drop policy if exists "comments author delete" on public.post_comments;
create policy "comments author delete" on public.post_comments for delete to authenticated using (auth.uid()=author_id);

drop policy if exists "discussion public read" on public.discussion_messages;
create policy "discussion public read" on public.discussion_messages for select using (true);
drop policy if exists "discussion authenticated insert" on public.discussion_messages;
create policy "discussion authenticated insert" on public.discussion_messages for insert to authenticated with check (auth.uid()=author_id);
drop policy if exists "discussion author delete" on public.discussion_messages;
create policy "discussion author delete" on public.discussion_messages for delete to authenticated using (auth.uid()=author_id);

drop policy if exists "reactions public read" on public.discussion_reactions;
create policy "reactions public read" on public.discussion_reactions for select using (true);
drop policy if exists "reactions owner insert" on public.discussion_reactions;
create policy "reactions owner insert" on public.discussion_reactions for insert to authenticated with check (auth.uid()=user_id);
drop policy if exists "reactions owner delete" on public.discussion_reactions;
create policy "reactions owner delete" on public.discussion_reactions for delete to authenticated using (auth.uid()=user_id);

-- Image bucket. Public read, owner-only upload/delete.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('community-images','community-images',true,5242880,array['image/png','image/jpeg','image/gif','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/png','image/jpeg','image/gif','image/webp'];
drop policy if exists "community image public read" on storage.objects;
create policy "community image public read" on storage.objects for select using (bucket_id='community-images');
drop policy if exists "community image owner upload" on storage.objects;
create policy "community image owner upload" on storage.objects for insert to authenticated with check (bucket_id='community-images' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "community image owner delete" on storage.objects;
create policy "community image owner delete" on storage.objects for delete to authenticated using (bucket_id='community-images' and (storage.foldername(name))[1]=auth.uid()::text);

-- Realtime: add chat messages to the Supabase Realtime publication.
do $$ begin
  alter publication supabase_realtime add table public.discussion_messages;
exception when duplicate_object then null;
end $$;
