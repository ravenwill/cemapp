-- CEMAPP — esquema inicial (Supabase / Postgres) com RLS.
-- Executar no SQL Editor do painel. Seguro para rodar mais de uma vez.

-- ========== PERFIS E PERMISSÕES ==========
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  avatar_url text,
  birthday date,
  is_master boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.user_features (
  user_id uuid references public.profiles(id) on delete cascade,
  feature text not null check (feature in ('avisos','agenda','louvor','admin')),
  primary key (user_id, feature)
);

-- Cria o perfil automaticamente no primeiro login com Google.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name, avatar_url)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
          new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing;
  insert into public.user_features (user_id, feature)
  values (new.id,'avisos'),(new.id,'agenda') on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.is_master() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_master from public.profiles where id = auth.uid()), false)
$$;

-- ========== MINISTÉRIO DE LOUVOR ==========
create table if not exists public.ministries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.ministry_members (
  ministry_id uuid references public.ministries(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  is_leader boolean not null default false,
  primary key (ministry_id, user_id)
);

create table if not exists public.roles (          -- funções (vocal, violão...)
  id uuid primary key default gen_random_uuid(),
  ministry_id uuid not null references public.ministries(id) on delete cascade,
  name text not null
);

create or replace function public.is_member(mid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_master() or exists (
    select 1 from public.ministry_members where ministry_id = mid and user_id = auth.uid())
$$;

create or replace function public.is_leader(mid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_master() or exists (
    select 1 from public.ministry_members where ministry_id = mid and user_id = auth.uid() and is_leader)
$$;

create table if not exists public.songs (
  id uuid primary key default gen_random_uuid(),
  ministry_id uuid not null references public.ministries(id) on delete cascade,
  title text not null,
  artist text,
  album text,
  cover_url text,
  classification text,
  created_at timestamptz not null default now()
);

create table if not exists public.song_versions (
  id uuid primary key default gen_random_uuid(),
  song_id uuid not null references public.songs(id) on delete cascade,
  name text not null default 'Original',
  key text, bpm int, duration_seconds int
);

create table if not exists public.song_links (
  id uuid primary key default gen_random_uuid(),
  song_id uuid not null references public.songs(id) on delete cascade,
  kind text not null check (kind in ('letra','cifra','audio','video','outro')),
  url text not null
);

create table if not exists public.schedules (
  id uuid primary key default gen_random_uuid(),
  ministry_id uuid not null references public.ministries(id) on delete cascade,
  title text not null,
  starts_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.schedule_members (
  schedule_id uuid references public.schedules(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  role_id uuid references public.roles(id) on delete set null,
  status text not null default 'pendente' check (status in ('pendente','confirmado','recusado')),
  primary key (schedule_id, user_id)
);

create table if not exists public.schedule_songs (
  schedule_id uuid references public.schedules(id) on delete cascade,
  version_id uuid references public.song_versions(id) on delete cascade,
  position int not null default 0,
  primary key (schedule_id, version_id)
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  ministry_id uuid references public.ministries(id) on delete cascade,
  title text not null,
  body text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  ministry_id uuid not null references public.ministries(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id),
  body text not null,
  created_at timestamptz not null default now()
);

-- ========== RLS ==========
alter table public.profiles enable row level security;
alter table public.user_features enable row level security;
alter table public.ministries enable row level security;
alter table public.ministry_members enable row level security;
alter table public.roles enable row level security;
alter table public.songs enable row level security;
alter table public.song_versions enable row level security;
alter table public.song_links enable row level security;
alter table public.schedules enable row level security;
alter table public.schedule_members enable row level security;
alter table public.schedule_songs enable row level security;
alter table public.announcements enable row level security;
alter table public.messages enable row level security;

-- perfis: todo logado lê; cada um edita o seu (sem mudar is_master); master edita todos
drop policy if exists p_profiles_read on public.profiles;
create policy p_profiles_read on public.profiles for select to authenticated using (true);
drop policy if exists p_profiles_self on public.profiles;
create policy p_profiles_self on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid() and is_master = (select is_master from public.profiles where id = auth.uid()));
drop policy if exists p_profiles_master on public.profiles;
create policy p_profiles_master on public.profiles for update to authenticated
  using (public.is_master()) with check (public.is_master());

-- permissões por função: o usuário lê as suas; só o master altera
drop policy if exists p_features_read on public.user_features;
create policy p_features_read on public.user_features for select to authenticated
  using (user_id = auth.uid() or public.is_master());
drop policy if exists p_features_master on public.user_features;
create policy p_features_master on public.user_features for all to authenticated
  using (public.is_master()) with check (public.is_master());

-- ministérios e dados do louvor: membros leem; líder/master escrevem
do $$
declare t text;
begin
  foreach t in array array['roles','songs','schedules','announcements'] loop
    execute format('drop policy if exists p_%1$s_read on public.%1$s', t);
    execute format('create policy p_%1$s_read on public.%1$s for select to authenticated using (public.is_member(ministry_id))', t);
    execute format('drop policy if exists p_%1$s_write on public.%1$s', t);
    execute format('create policy p_%1$s_write on public.%1$s for all to authenticated using (public.is_leader(ministry_id)) with check (public.is_leader(ministry_id))', t);
  end loop;
end $$;

drop policy if exists p_ministries_read on public.ministries;
create policy p_ministries_read on public.ministries for select to authenticated using (public.is_member(id));
drop policy if exists p_ministries_write on public.ministries;
create policy p_ministries_write on public.ministries for all to authenticated using (public.is_master()) with check (public.is_master());

drop policy if exists p_mm_read on public.ministry_members;
create policy p_mm_read on public.ministry_members for select to authenticated using (public.is_member(ministry_id));
drop policy if exists p_mm_write on public.ministry_members;
create policy p_mm_write on public.ministry_members for all to authenticated using (public.is_leader(ministry_id)) with check (public.is_leader(ministry_id));

-- tabelas filhas de músicas
do $$
declare t text;
begin
  foreach t in array array['song_versions','song_links'] loop
    execute format('drop policy if exists p_%1$s_read on public.%1$s', t);
    execute format('create policy p_%1$s_read on public.%1$s for select to authenticated using (exists (select 1 from public.songs s where s.id = song_id and public.is_member(s.ministry_id)))', t);
    execute format('drop policy if exists p_%1$s_write on public.%1$s', t);
    execute format('create policy p_%1$s_write on public.%1$s for all to authenticated using (exists (select 1 from public.songs s where s.id = song_id and public.is_leader(s.ministry_id))) with check (exists (select 1 from public.songs s where s.id = song_id and public.is_leader(s.ministry_id)))', t);
  end loop;
end $$;

-- escalas: membros leem; líder escreve; cada escalado altera só o próprio status
drop policy if exists p_sm_read on public.schedule_members;
create policy p_sm_read on public.schedule_members for select to authenticated
  using (exists (select 1 from public.schedules s where s.id = schedule_id and public.is_member(s.ministry_id)));
drop policy if exists p_sm_write on public.schedule_members;
create policy p_sm_write on public.schedule_members for all to authenticated
  using (exists (select 1 from public.schedules s where s.id = schedule_id and public.is_leader(s.ministry_id)))
  with check (exists (select 1 from public.schedules s where s.id = schedule_id and public.is_leader(s.ministry_id)));
drop policy if exists p_sm_self on public.schedule_members;
create policy p_sm_self on public.schedule_members for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists p_ss_read on public.schedule_songs;
create policy p_ss_read on public.schedule_songs for select to authenticated
  using (exists (select 1 from public.schedules s where s.id = schedule_id and public.is_member(s.ministry_id)));
drop policy if exists p_ss_write on public.schedule_songs;
create policy p_ss_write on public.schedule_songs for all to authenticated
  using (exists (select 1 from public.schedules s where s.id = schedule_id and public.is_leader(s.ministry_id)))
  with check (exists (select 1 from public.schedules s where s.id = schedule_id and public.is_leader(s.ministry_id)));

-- chat: membros leem e escrevem como si mesmos
drop policy if exists p_msg_read on public.messages;
create policy p_msg_read on public.messages for select to authenticated using (public.is_member(ministry_id));
drop policy if exists p_msg_insert on public.messages;
create policy p_msg_insert on public.messages for insert to authenticated
  with check (user_id = auth.uid() and public.is_member(ministry_id));
