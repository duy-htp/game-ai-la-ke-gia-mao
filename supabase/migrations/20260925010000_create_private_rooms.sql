create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  host_id uuid references public.profiles (id) on delete restrict,
  created_by uuid not null references public.profiles (id) on delete restrict,
  game_type text not null,
  status text not null default 'waiting',
  max_players integer not null default 6,
  create_request_id uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),

  constraint rooms_code_format
    check (code ~ '^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$'),
  constraint rooms_game_type_supported check (game_type = 'impostor'),
  constraint rooms_status_supported check (status in ('waiting', 'closed')),
  constraint rooms_max_players_range check (max_players between 3 and 10),
  constraint rooms_waiting_has_host check (status <> 'waiting' or host_id is not null),
  constraint rooms_create_idempotency unique (created_by, create_request_id)
);

create table public.room_players (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms (id) on delete restrict,
  player_id uuid not null references public.profiles (id) on delete restrict,
  seat integer not null,
  joined_at timestamptz not null default statement_timestamp(),
  left_at timestamptz,

  constraint room_players_seat_positive check (seat >= 1),
  constraint room_players_left_after_joined
    check (left_at is null or left_at >= joined_at)
);

create unique index rooms_active_code_unique
  on public.rooms (code)
  where status = 'waiting';

create index rooms_code_lookup on public.rooms (code, status);

create unique index room_players_active_room_player_unique
  on public.room_players (room_id, player_id)
  where left_at is null;

create unique index room_players_active_seat_unique
  on public.room_players (room_id, seat)
  where left_at is null;

create unique index room_players_one_active_room_per_player
  on public.room_players (player_id)
  where left_at is null;

create index room_players_active_room_order
  on public.room_players (room_id, joined_at, seat, player_id)
  where left_at is null;

alter table public.rooms enable row level security;
alter table public.rooms force row level security;
alter table public.room_players enable row level security;
alter table public.room_players force row level security;

revoke all on table public.rooms from public, anon, authenticated;
revoke all on table public.room_players from public, anon, authenticated;
revoke all on sequence public.room_players_id_seq from public, anon, authenticated;

create trigger rooms_set_updated_at
before update on public.rooms
for each row execute function public.set_updated_at();

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create function private.room_snapshot(p_room_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'room_id', r.id,
    'code', r.code,
    'game_type', r.game_type,
    'status', r.status,
    'max_players', r.max_players,
    'host_id', r.host_id,
    'members', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'player_id', rp.player_id,
          'username', p.username,
          'avatar_id', p.avatar_id,
          'seat', rp.seat,
          'is_host', rp.player_id = r.host_id,
          'joined_at', rp.joined_at
        ) order by rp.seat
      )
      from public.room_players rp
      join public.profiles p on p.id = rp.player_id
      where rp.room_id = r.id and rp.left_at is null
    ), '[]'::jsonb)
  )
  from public.rooms r
  where r.id = p_room_id;
$$;

revoke all on function private.room_snapshot(uuid) from public, anon, authenticated;

create function private.assert_profile(p_user_id uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'profile_required' using errcode = 'P0001';
  end if;
end;
$$;

revoke all on function private.assert_profile(uuid) from public, anon, authenticated;

create function public.get_current_room()
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_room_id uuid;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = 'P0001';
  end if;

  select rp.room_id into v_room_id
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  where rp.player_id = v_user_id
    and rp.left_at is null
    and r.status = 'waiting';

  if v_room_id is null then
    return null;
  end if;
  return private.room_snapshot(v_room_id);
end;
$$;

create function public.create_room(
  p_game_type text,
  p_max_players integer,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing_room_id uuid;
  v_room_id uuid;
  v_code text;
  v_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  v_bytes bytea;
  v_attempt integer;
  v_index integer;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = 'P0001';
  end if;
  if p_request_id is null then
    raise exception 'room_operation_failed' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select r.id into v_existing_room_id
  from public.rooms r
  where r.created_by = v_user_id and r.create_request_id = p_request_id;

  if v_existing_room_id is not null then
    return private.room_snapshot(v_existing_room_id);
  end if;

  perform private.assert_profile(v_user_id);

  if exists (
    select 1 from public.room_players rp
    where rp.player_id = v_user_id and rp.left_at is null
  ) then
    raise exception 'already_in_another_room' using errcode = 'P0001';
  end if;
  if p_game_type is distinct from 'impostor' then
    raise exception 'unsupported_game_type' using errcode = 'P0001';
  end if;
  if p_max_players is null or p_max_players not between 3 and 10 then
    raise exception 'invalid_max_players' using errcode = 'P0001';
  end if;

  for v_attempt in 1..32 loop
    v_bytes := extensions.gen_random_bytes(6);
    v_code := '';
    for v_index in 0..5 loop
      v_code := v_code || substr(
        v_alphabet,
        (get_byte(v_bytes, v_index) % char_length(v_alphabet)) + 1,
        1
      );
    end loop;

    begin
      insert into public.rooms (
        code, host_id, created_by, game_type, status, max_players,
        create_request_id
      ) values (
        v_code, v_user_id, v_user_id, p_game_type, 'waiting', p_max_players,
        p_request_id
      ) returning id into v_room_id;
      exit;
    exception when unique_violation then
      v_room_id := null;
    end;
  end loop;

  if v_room_id is null then
    raise exception 'room_operation_failed' using errcode = 'P0001';
  end if;

  insert into public.room_players (room_id, player_id, seat)
  values (v_room_id, v_user_id, 1);

  return private.room_snapshot(v_room_id);
end;
$$;

create function public.join_room(p_room_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_code text := upper(btrim(p_room_code));
  v_room public.rooms;
  v_active_room_id uuid;
  v_active_room_code text;
  v_member_count integer;
  v_seat integer;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = 'P0001';
  end if;
  if v_code is null or v_code !~ '^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$' then
    raise exception 'invalid_room_code' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));
  perform private.assert_profile(v_user_id);

  select rp.room_id, r.code into v_active_room_id, v_active_room_code
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  where rp.player_id = v_user_id and rp.left_at is null;

  if v_active_room_id is not null then
    if v_active_room_code = v_code then
      return private.room_snapshot(v_active_room_id);
    end if;
    raise exception 'already_in_another_room' using errcode = 'P0001';
  end if;

  select * into v_room
  from public.rooms r
  where r.code = v_code and r.status = 'waiting'
  for update;

  if not found then
    if exists (select 1 from public.rooms r where r.code = v_code) then
      raise exception 'room_closed' using errcode = 'P0001';
    end if;
    raise exception 'room_not_found' using errcode = 'P0001';
  end if;

  select count(*)::integer into v_member_count
  from public.room_players rp
  where rp.room_id = v_room.id and rp.left_at is null;

  if v_member_count >= v_room.max_players then
    raise exception 'room_full' using errcode = 'P0001';
  end if;

  select gs.candidate_seat into v_seat
  from generate_series(1, v_room.max_players) as gs(candidate_seat)
  where not exists (
    select 1 from public.room_players rp
    where rp.room_id = v_room.id
      and rp.seat = gs.candidate_seat
      and rp.left_at is null
  )
  order by gs.candidate_seat
  limit 1;

  if v_seat is null then
    raise exception 'room_full' using errcode = 'P0001';
  end if;

  insert into public.room_players (room_id, player_id, seat)
  values (v_room.id, v_user_id, v_seat);

  return private.room_snapshot(v_room.id);
end;
$$;

create function public.leave_room()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.rooms;
  v_next_host uuid;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select r.* into v_room
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  where rp.player_id = v_user_id and rp.left_at is null
  for update of r;

  if not found then
    return null;
  end if;

  update public.room_players
  set left_at = statement_timestamp()
  where room_id = v_room.id
    and player_id = v_user_id
    and left_at is null;

  if v_room.host_id = v_user_id then
    select rp.player_id into v_next_host
    from public.room_players rp
    where rp.room_id = v_room.id and rp.left_at is null
    order by rp.joined_at, rp.seat, rp.player_id
    limit 1;

    if v_next_host is null then
      update public.rooms
      set status = 'closed', host_id = null
      where id = v_room.id;
    else
      update public.rooms
      set host_id = v_next_host
      where id = v_room.id;
    end if;
  end if;

  return null;
end;
$$;

revoke all on function public.get_current_room() from public, anon, authenticated;
revoke all on function public.create_room(text, integer, uuid)
  from public, anon, authenticated;
revoke all on function public.join_room(text) from public, anon, authenticated;
revoke all on function public.leave_room() from public, anon, authenticated;

grant execute on function public.get_current_room() to authenticated;
grant execute on function public.create_room(text, integer, uuid) to authenticated;
grant execute on function public.join_room(text) to authenticated;
grant execute on function public.leave_room() to authenticated;
