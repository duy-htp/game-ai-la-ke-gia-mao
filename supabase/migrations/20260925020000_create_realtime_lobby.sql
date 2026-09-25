create table public.categories (
  id bigint generated always as identity primary key,
  key text not null unique,
  name_vi text not null,
  name_en text not null,
  is_active boolean not null default true,
  is_premium boolean not null default false,
  sort_order integer not null,
  constraint categories_key_format check (key ~ '^[a-z][a-z_]*$')
);

insert into public.categories (key, name_vi, name_en, sort_order) values
  ('food', 'Đồ ăn', 'Food', 10),
  ('animals', 'Động vật', 'Animals', 20),
  ('places', 'Địa điểm', 'Places', 30),
  ('objects', 'Đồ vật', 'Objects', 40),
  ('jobs', 'Nghề nghiệp', 'Jobs', 50),
  ('sports', 'Thể thao', 'Sports', 60),
  ('entertainment', 'Giải trí', 'Entertainment', 70),
  ('vietnam', 'Việt Nam', 'Vietnam', 80),
  ('friends', 'Bạn bè', 'Friends', 90),
  ('relationships', 'Các mối quan hệ', 'Relationships', 100);

alter table public.categories enable row level security;
alter table public.categories force row level security;
revoke all on table public.categories from public, anon, authenticated;
revoke all on sequence public.categories_id_seq from public, anon, authenticated;
grant select on table public.categories to authenticated;
create policy categories_read_active on public.categories
  for select to authenticated using (is_active);

alter table public.rooms
  add column revision bigint not null default 1,
  add column impostor_count integer not null default 1,
  add column category_id bigint references public.categories (id) on delete restrict,
  add column clue_seconds integer not null default 30,
  add column discussion_seconds integer not null default 90,
  add constraint rooms_revision_positive check (revision >= 1),
  add constraint rooms_impostor_count check (impostor_count in (1, 2)),
  add constraint rooms_clue_seconds check (clue_seconds in (15, 30, 45, 60)),
  add constraint rooms_discussion_seconds check (discussion_seconds in (60, 90, 120));

alter table public.room_players
  add column is_ready boolean not null default false;

create function private.can_access_room_topic(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and p_topic ~ '^room:[0-9a-f-]{36}$'
    and exists (
      select 1
      from public.room_players rp
      join public.rooms r on r.id = rp.room_id
      where rp.player_id = auth.uid()
        and rp.left_at is null
        and r.status = 'waiting'
        and ('room:' || r.id::text) = p_topic
    );
$$;
revoke all on function private.can_access_room_topic(text)
  from public, anon, authenticated;
grant execute on function private.can_access_room_topic(text) to authenticated;

create policy lobby_realtime_receive on realtime.messages
  for select to authenticated
  using (
    extension in ('broadcast', 'presence')
    and private.can_access_room_topic((select realtime.topic()))
  );

create policy lobby_presence_send on realtime.messages
  for insert to authenticated
  with check (
    extension = 'presence'
    and private.can_access_room_topic((select realtime.topic()))
  );

create function private.broadcast_room_changed(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object('room_id', p_room_id),
    'room_changed',
    'room:' || p_room_id::text,
    true
  );
end;
$$;
revoke all on function private.broadcast_room_changed(uuid)
  from public, anon, authenticated;

create function private.bump_room_after_membership_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room_id uuid := coalesce(new.room_id, old.room_id);
begin
  update public.rooms
  set revision = revision + 1
  where id = v_room_id;
  return coalesce(new, old);
end;
$$;

create trigger room_players_bump_room_revision
after insert or update of left_at, is_ready on public.room_players
for each row execute function private.bump_room_after_membership_change();

create function private.broadcast_room_row_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.broadcast_room_changed(new.id);
  return new;
end;
$$;

create trigger rooms_broadcast_change
after insert or update on public.rooms
for each row execute function private.broadcast_room_row_changed();

create or replace function private.room_snapshot(p_room_id uuid)
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
    'revision', r.revision,
    'settings', jsonb_build_object(
      'impostor_count', r.impostor_count,
      'category_key', c.key,
      'clue_seconds', r.clue_seconds,
      'discussion_seconds', r.discussion_seconds
    ),
    'can_start', r.status = 'waiting'
      and r.host_id is not null
      and exists (
        select 1 from public.room_players host
        where host.room_id = r.id and host.player_id = r.host_id and host.left_at is null
      )
      and (select count(*) from public.room_players rp where rp.room_id = r.id and rp.left_at is null) >= 3
      and not exists (
        select 1 from public.room_players rp
        where rp.room_id = r.id and rp.left_at is null
          and rp.player_id <> r.host_id and not rp.is_ready
      )
      and (r.impostor_count = 1 or (
        r.impostor_count = 2
        and (select count(*) from public.room_players rp where rp.room_id = r.id and rp.left_at is null) >= 7
      ))
      and (r.category_id is null or c.is_active),
    'members', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'player_id', rp.player_id,
          'username', p.username,
          'avatar_id', p.avatar_id,
          'seat', rp.seat,
          'is_host', rp.player_id = r.host_id,
          'is_ready', case when rp.player_id = r.host_id then false else rp.is_ready end,
          'joined_at', rp.joined_at
        ) order by rp.seat
      )
      from public.room_players rp
      join public.profiles p on p.id = rp.player_id
      where rp.room_id = r.id and rp.left_at is null
    ), '[]'::jsonb)
  )
  from public.rooms r
  left join public.categories c on c.id = r.category_id
  where r.id = p_room_id;
$$;

create function public.set_ready(p_is_ready boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.rooms;
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = 'P0001';
  end if;
  perform private.assert_profile(v_user_id);

  select r.* into v_room
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  where rp.player_id = v_user_id and rp.left_at is null
  for update of r;

  if not found then raise exception 'not_room_member' using errcode = 'P0001'; end if;
  if v_room.status <> 'waiting' then raise exception 'room_closed' using errcode = 'P0001'; end if;
  if v_room.host_id = v_user_id then raise exception 'host_ready_not_allowed' using errcode = 'P0001'; end if;
  if p_is_ready is null then raise exception 'invalid_ready_state' using errcode = 'P0001'; end if;

  update public.room_players
  set is_ready = p_is_ready
  where room_id = v_room.id and player_id = v_user_id and left_at is null
    and is_ready is distinct from p_is_ready;

  return private.room_snapshot(v_room.id);
end;
$$;

create function public.update_room_settings(
  p_impostor_count integer,
  p_category_key text,
  p_clue_seconds integer,
  p_discussion_seconds integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_room public.rooms;
  v_category_id bigint;
  v_category_key text := nullif(lower(btrim(p_category_key)), 'random');
  v_changed boolean;
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode = 'P0001'; end if;
  perform private.assert_profile(v_user_id);

  select r.* into v_room from public.rooms r
  where r.host_id = v_user_id and r.status = 'waiting' for update;
  if not found then raise exception 'host_required' using errcode = 'P0001'; end if;
  if p_impostor_count not in (1, 2) or (p_impostor_count = 2 and v_room.max_players < 7) then
    raise exception 'invalid_impostor_count' using errcode = 'P0001';
  end if;
  if p_clue_seconds not in (15, 30, 45, 60) then raise exception 'invalid_clue_time' using errcode = 'P0001'; end if;
  if p_discussion_seconds not in (60, 90, 120) then raise exception 'invalid_discussion_time' using errcode = 'P0001'; end if;
  if p_category_key is null then raise exception 'invalid_category' using errcode = 'P0001'; end if;

  if v_category_key is not null then
    select id into v_category_id from public.categories
    where key = v_category_key and is_active;
    if v_category_id is null then raise exception 'invalid_category' using errcode = 'P0001'; end if;
  end if;

  v_changed := v_room.impostor_count is distinct from p_impostor_count
    or v_room.category_id is distinct from v_category_id
    or v_room.clue_seconds is distinct from p_clue_seconds
    or v_room.discussion_seconds is distinct from p_discussion_seconds;

  if v_changed then
    update public.rooms set
      impostor_count = p_impostor_count,
      category_id = v_category_id,
      clue_seconds = p_clue_seconds,
      discussion_seconds = p_discussion_seconds,
      revision = revision + 1
    where id = v_room.id;
    update public.room_players set is_ready = false
    where room_id = v_room.id and left_at is null and player_id <> v_user_id and is_ready;
  end if;

  return private.room_snapshot(v_room.id);
end;
$$;

create function private.clear_new_host_ready()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.host_id is distinct from old.host_id and new.host_id is not null then
    update public.room_players set is_ready = false
    where room_id = new.id and player_id = new.host_id and left_at is null and is_ready;
  end if;
  return new;
end;
$$;
create trigger rooms_clear_new_host_ready
after update of host_id on public.rooms
for each row execute function private.clear_new_host_ready();

revoke all on function public.set_ready(boolean) from public, anon, authenticated;
revoke all on function public.update_room_settings(integer, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.set_ready(boolean) to authenticated;
grant execute on function public.update_room_settings(integer, text, integer, integer)
  to authenticated;
