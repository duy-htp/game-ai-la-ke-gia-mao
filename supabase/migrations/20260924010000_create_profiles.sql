create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null,
  avatar_id text not null,
  coins integer not null default 0,
  xp integer not null default 0,
  level integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),

  constraint profiles_username_trimmed
    check (username = btrim(username)),
  constraint profiles_username_length
    check (char_length(username) between 2 and 20),
  constraint profiles_username_no_control_characters
    check (username !~ '[[:cntrl:]]'),
  constraint profiles_avatar_allowed
    check (avatar_id = any (array[
      'avatar_01', 'avatar_02', 'avatar_03', 'avatar_04',
      'avatar_05', 'avatar_06', 'avatar_07', 'avatar_08',
      'avatar_09', 'avatar_10', 'avatar_11', 'avatar_12'
    ]::text[])),
  constraint profiles_coins_nonnegative check (coins >= 0),
  constraint profiles_xp_nonnegative check (xp >= 0),
  constraint profiles_level_positive check (level >= 1)
);

comment on table public.profiles is
  'Private player profiles. Economy fields are server-controlled.';

alter table public.profiles enable row level security;
alter table public.profiles force row level security;

create policy profiles_select_own
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

revoke all on table public.profiles from public, anon, authenticated;
grant select (
  id, username, avatar_id, coins, xp, level, created_at, updated_at
) on table public.profiles to authenticated;

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := statement_timestamp();
  return new;
end;
$$;

revoke all on function public.set_updated_at() from public, anon, authenticated;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create function public.complete_profile(
  p_username text,
  p_avatar_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_username text := btrim(p_username);
  v_profile public.profiles;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = 'P0001';
  end if;

  if v_username is null or char_length(v_username) < 2 then
    raise exception 'Username must contain at least 2 characters'
      using errcode = 'P0001';
  end if;
  if char_length(v_username) > 20 then
    raise exception 'Username cannot exceed 20 characters'
      using errcode = 'P0001';
  end if;
  if v_username ~ '[[:cntrl:]]' then
    raise exception 'Username contains control characters'
      using errcode = 'P0001';
  end if;
  if p_avatar_id is null or p_avatar_id <> all (array[
    'avatar_01', 'avatar_02', 'avatar_03', 'avatar_04',
    'avatar_05', 'avatar_06', 'avatar_07', 'avatar_08',
    'avatar_09', 'avatar_10', 'avatar_11', 'avatar_12'
  ]::text[]) then
    raise exception 'Invalid avatar' using errcode = 'P0001';
  end if;

  insert into public.profiles (
    id, username, avatar_id, coins, xp, level
  ) values (
    v_user_id, v_username, p_avatar_id, 0, 0, 1
  )
  on conflict (id) do nothing;

  select * into strict v_profile
  from public.profiles
  where id = v_user_id;

  return to_jsonb(v_profile);
end;
$$;

comment on function public.complete_profile(text, text) is
  'Idempotently creates auth.uid() profile with server-owned economy defaults.';

revoke all on function public.complete_profile(text, text)
  from public, anon, authenticated;
grant execute on function public.complete_profile(text, text)
  to authenticated;
