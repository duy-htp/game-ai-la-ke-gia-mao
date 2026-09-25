create extension if not exists unaccent with schema extensions;

alter table public.games
  add column impostor_count integer,
  add column clue_seconds integer,
  add column discussion_seconds integer;

update public.games g set
  impostor_count = r.impostor_count,
  clue_seconds = r.clue_seconds,
  discussion_seconds = r.discussion_seconds
from public.rooms r where r.id = g.room_id;

alter table public.games
  alter column impostor_count set not null,
  alter column clue_seconds set not null,
  alter column discussion_seconds set not null,
  add constraint games_impostor_count_valid check (impostor_count between 1 and 2),
  add constraint games_clue_seconds_valid check (clue_seconds in (15, 30, 45, 60)),
  add constraint games_discussion_seconds_valid check (discussion_seconds in (60, 90, 120));

alter table public.game_players add column role_acknowledged_at timestamptz;

create table public.game_turns (
  id bigint generated always as identity primary key,
  game_id uuid not null references public.games(id) on delete restrict,
  turn_index integer not null check (turn_index >= 1),
  player_id uuid not null references public.profiles(id) on delete restrict,
  status text not null check (status in ('active', 'submitted', 'timed_out')),
  started_at timestamptz not null,
  ends_at timestamptz not null,
  completed_at timestamptz,
  failed_attempts smallint not null default 0 check (failed_attempts between 0 and 5),
  constraint game_turns_game_turn_unique unique(game_id, turn_index),
  constraint game_turns_window_valid check (ends_at >= started_at),
  constraint game_turns_completion_valid check (
    (status = 'active' and completed_at is null) or
    (status <> 'active' and completed_at is not null)
  )
);
create unique index game_turns_one_active_per_game
  on public.game_turns(game_id) where status = 'active';

create table public.clues (
  id bigint generated always as identity primary key,
  game_id uuid not null references public.games(id) on delete restrict,
  turn_id bigint not null references public.game_turns(id) on delete restrict,
  player_id uuid not null references public.profiles(id) on delete restrict,
  turn_index integer not null check (turn_index >= 1),
  clue_text text not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint clues_turn_unique unique(turn_id),
  constraint clues_game_turn_unique unique(game_id, turn_index),
  constraint clues_not_blank check (btrim(clue_text) <> ''),
  constraint clues_length check (char_length(clue_text) between 1 and 80)
);

alter table public.game_turns enable row level security;
alter table public.game_turns force row level security;
alter table public.clues enable row level security;
alter table public.clues force row level security;
revoke all on table public.game_turns, public.clues from public, anon, authenticated;
revoke all on sequence public.game_turns_id_seq, public.clues_id_seq from public, anon, authenticated;

create function private.normalize_game_phrase(p_value text)
returns text language sql immutable strict set search_path = '' as $$
  select btrim(regexp_replace(
    lower(extensions.unaccent(normalize(p_value, NFC))),
    '[^a-z0-9]+', ' ', 'g'
  ));
$$;
revoke all on function private.normalize_game_phrase(text) from public, anon, authenticated;

create function private.clue_contains_phrase(p_clue text, p_word_vi text, p_word_en text)
returns boolean language sql immutable strict set search_path = '' as $$
  select (' ' || private.normalize_game_phrase(p_clue) || ' ') like
           ('% ' || private.normalize_game_phrase(p_word_vi) || ' %')
      or (' ' || private.normalize_game_phrase(p_clue) || ' ') like
           ('% ' || private.normalize_game_phrase(p_word_en) || ' %');
$$;
revoke all on function private.clue_contains_phrase(text,text,text) from public, anon, authenticated;

create function private.start_clue_phase(p_game_id uuid, p_now timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
declare v_seconds integer; v_player_id uuid;
begin
  select g.clue_seconds into strict v_seconds from public.games g where g.id=p_game_id;
  select gp.player_id into strict v_player_id from public.game_players gp
    where gp.game_id=p_game_id and gp.turn_order=1;
  update public.games set status='clue', phase_started_at=p_now,
    phase_ends_at=p_now+make_interval(secs=>v_seconds), revision=revision+1
    where id=p_game_id and status='role_reveal';
  if found then
    insert into public.game_turns(game_id,turn_index,player_id,status,started_at,ends_at)
      values(p_game_id,1,v_player_id,'active',p_now,p_now+make_interval(secs=>v_seconds));
  end if;
end;
$$;
revoke all on function private.start_clue_phase(uuid,timestamptz) from public, anon, authenticated;

create function private.complete_clue_turn(p_game_id uuid, p_turn_id bigint, p_status text, p_now timestamptz)
returns void language plpgsql security definer set search_path = '' as $$
declare v_turn_index integer; v_next_player uuid; v_clue_seconds integer; v_discussion_seconds integer;
begin
  update public.game_turns set status=p_status, completed_at=p_now
    where id=p_turn_id and game_id=p_game_id and status='active'
    returning turn_index into strict v_turn_index;
  select gp.player_id into v_next_player from public.game_players gp
    where gp.game_id=p_game_id and gp.turn_order=v_turn_index+1;
  if v_next_player is null then
    select g.discussion_seconds into strict v_discussion_seconds from public.games g where g.id=p_game_id;
    update public.games set status='discussion', phase_started_at=p_now,
      phase_ends_at=p_now+make_interval(secs=>v_discussion_seconds), revision=revision+1
      where id=p_game_id;
  else
    select g.clue_seconds into strict v_clue_seconds from public.games g where g.id=p_game_id;
    insert into public.game_turns(game_id,turn_index,player_id,status,started_at,ends_at)
      values(p_game_id,v_turn_index+1,v_next_player,'active',p_now,p_now+make_interval(secs=>v_clue_seconds));
    update public.games set phase_started_at=p_now,
      phase_ends_at=p_now+make_interval(secs=>v_clue_seconds), revision=revision+1
      where id=p_game_id;
  end if;
end;
$$;
revoke all on function private.complete_clue_turn(uuid,bigint,text,timestamptz) from public, anon, authenticated;

create or replace function private.game_snapshot(p_game_id uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'game_id',g.id,'room_id',g.room_id,'round_number',g.round_number,'status',g.status,
    'phase_started_at',g.phase_started_at,'phase_ends_at',g.phase_ends_at,
    'server_now',clock_timestamp(),'revision',g.revision,
    'participants',coalesce((select jsonb_agg(jsonb_build_object(
      'player_id',gp.player_id,'username',p.username,'avatar_id',p.avatar_id,
      'role_acknowledged',gp.role_acknowledged_at is not null
    ) order by gp.turn_order) from public.game_players gp join public.profiles p on p.id=gp.player_id
      where gp.game_id=g.id),'[]'::jsonb),
    'turns',coalesce((select jsonb_agg(jsonb_build_object(
      'turn_id',gt.id,'turn_index',gt.turn_index,'player_id',gt.player_id,'status',gt.status,
      'started_at',gt.started_at,'ends_at',gt.ends_at,'completed_at',gt.completed_at,
      'clue_text',c.clue_text
    ) order by gt.turn_index) from public.game_turns gt left join public.clues c on c.turn_id=gt.id
      where gt.game_id=g.id),'[]'::jsonb)
  ) from public.games g where g.id=p_game_id;
$$;

create or replace function public.start_game(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid(); v_room public.rooms; v_game_id uuid;
  v_category_id bigint; v_keyword_id bigint; v_count integer; v_round integer;
  v_index integer := 0; v_player_id uuid;
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode='P0001'; end if;
  if p_request_id is null then raise exception 'invalid_start_request' using errcode='P0001'; end if;
  perform private.assert_profile(v_user_id);
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text,1));
  select g.id into v_game_id from public.games g where g.started_by=v_user_id and g.start_request_id=p_request_id;
  if v_game_id is not null then return private.game_snapshot(v_game_id); end if;
  select r.* into v_room from public.room_players rp join public.rooms r on r.id=rp.room_id
    where rp.player_id=v_user_id and rp.left_at is null for update of r;
  if not found then raise exception 'not_room_member' using errcode='P0001'; end if;
  if v_room.host_id<>v_user_id then raise exception 'not_host' using errcode='P0001'; end if;
  if v_room.status='in_game' or exists(select 1 from public.games g where g.room_id=v_room.id and g.status<>'result') then raise exception 'game_already_started' using errcode='P0001'; end if;
  if v_room.status<>'waiting' then raise exception 'room_closed' using errcode='P0001'; end if;
  select count(*)::integer into v_count from public.room_players rp where rp.room_id=v_room.id and rp.left_at is null;
  if v_count<3 then raise exception 'not_enough_players' using errcode='P0001'; end if;
  if v_count>v_room.max_players or exists(select 1 from public.room_players rp where rp.room_id=v_room.id and rp.left_at is null and rp.player_id<>v_user_id and not rp.is_ready) then raise exception 'players_not_ready' using errcode='P0001'; end if;
  if (v_count between 3 and 6 and v_room.impostor_count<>1) or (v_count between 7 and 10 and v_room.impostor_count not in (1,2)) then raise exception 'invalid_game_settings' using errcode='P0001'; end if;
  if v_room.category_id is null then
    select c.id into v_category_id from public.categories c where c.is_active and exists(select 1 from public.words w where w.category_id=c.id and w.is_active) order by encode(extensions.gen_random_bytes(16),'hex') limit 1;
  else select c.id into v_category_id from public.categories c where c.id=v_room.category_id and c.is_active; end if;
  if v_category_id is null then raise exception 'invalid_game_settings' using errcode='P0001'; end if;
  select w.id into v_keyword_id from public.words w where w.category_id=v_category_id and w.is_active order by encode(extensions.gen_random_bytes(16),'hex') limit 1;
  if v_keyword_id is null then raise exception 'no_eligible_words' using errcode='P0001'; end if;
  select coalesce(max(g.round_number),0)+1 into v_round from public.games g where g.room_id=v_room.id;
  insert into public.games(room_id,round_number,status,category_id,keyword_id,phase_started_at,phase_ends_at,
    started_by,start_request_id,impostor_count,clue_seconds,discussion_seconds)
  values(v_room.id,v_round,'role_reveal',v_category_id,v_keyword_id,clock_timestamp(),clock_timestamp()+interval '15 seconds',
    v_user_id,p_request_id,v_room.impostor_count,v_room.clue_seconds,v_room.discussion_seconds) returning id into v_game_id;
  for v_player_id in select rp.player_id from public.room_players rp where rp.room_id=v_room.id and rp.left_at is null order by encode(extensions.gen_random_bytes(16),'hex') loop
    v_index:=v_index+1; insert into public.game_players(game_id,player_id,role,turn_order) values(v_game_id,v_player_id,'normal',v_index);
  end loop;
  update public.game_players set role='impostor' where id in (select gp.id from public.game_players gp where gp.game_id=v_game_id order by encode(extensions.gen_random_bytes(16),'hex') limit v_room.impostor_count);
  update public.rooms set status='in_game',revision=revision+1 where id=v_room.id;
  return private.game_snapshot(v_game_id);
end;
$$;

create function public.acknowledge_role()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_user_id uuid:=auth.uid(); v_game public.games; v_now timestamptz:=clock_timestamp();
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode='P0001'; end if;
  select g.* into v_game from public.games g join public.game_players gp on gp.game_id=g.id
    where gp.player_id=v_user_id and g.status<>'result' order by g.created_at desc limit 1 for update of g;
  if not found then raise exception 'not_game_participant' using errcode='P0001'; end if;
  if v_game.status<>'role_reveal' then raise exception 'invalid_game_phase' using errcode='P0001'; end if;
  update public.game_players set role_acknowledged_at=v_now where game_id=v_game.id and player_id=v_user_id and role_acknowledged_at is null;
  if found then update public.games set revision=revision+1 where id=v_game.id; end if;
  if not exists(select 1 from public.game_players gp where gp.game_id=v_game.id and gp.role_acknowledged_at is null) then
    perform private.start_clue_phase(v_game.id,v_now);
  end if;
  return private.game_snapshot(v_game.id);
end;
$$;

create function public.advance_game_if_due()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_user_id uuid:=auth.uid(); v_game public.games; v_turn_id bigint; v_now timestamptz:=clock_timestamp();
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode='P0001'; end if;
  select g.* into v_game from public.games g join public.game_players gp on gp.game_id=g.id
    where gp.player_id=v_user_id and g.status<>'result' order by g.created_at desc limit 1 for update of g;
  if not found then raise exception 'not_game_participant' using errcode='P0001'; end if;
  if v_game.status='role_reveal' and v_game.phase_ends_at<=v_now then
    perform private.start_clue_phase(v_game.id,v_now);
  elsif v_game.status='clue' then
    select gt.id into v_turn_id from public.game_turns gt where gt.game_id=v_game.id and gt.status='active' and gt.ends_at<=v_now for update;
    if v_turn_id is not null then perform private.complete_clue_turn(v_game.id,v_turn_id,'timed_out',v_now); end if;
  end if;
  return private.game_snapshot(v_game.id);
end;
$$;

create function public.submit_clue(p_text text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_user_id uuid:=auth.uid(); v_game public.games; v_turn public.game_turns; v_text text;
  v_word_vi text; v_word_en text; v_now timestamptz:=clock_timestamp();
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode='P0001'; end if;
  select g.* into v_game from public.games g join public.game_players gp on gp.game_id=g.id
    where gp.player_id=v_user_id and g.status<>'result' order by g.created_at desc limit 1 for update of g;
  if not found then raise exception 'not_game_participant' using errcode='P0001'; end if;
  if v_game.status<>'clue' then raise exception 'invalid_game_phase' using errcode='P0001'; end if;
  select gt.* into v_turn from public.game_turns gt where gt.game_id=v_game.id and gt.status='active' for update;
  if not found or v_turn.player_id<>v_user_id then raise exception 'not_current_turn' using errcode='P0001'; end if;
  if v_turn.ends_at<=v_now then raise exception 'turn_expired' using errcode='P0001'; end if;
  v_text:=btrim(p_text);
  if v_text is null or char_length(v_text)<1 or char_length(v_text)>80 or v_text~'[[:cntrl:]]' then raise exception 'invalid_clue' using errcode='P0001'; end if;
  if v_turn.failed_attempts>=5 then raise exception 'invalid_clue' using errcode='P0001'; end if;
  select w.word_vi,w.word_en into strict v_word_vi,v_word_en from public.words w where w.id=v_game.keyword_id;
  if private.clue_contains_phrase(v_text,v_word_vi,v_word_en) then
    update public.game_turns set failed_attempts=least(failed_attempts+1,5) where id=v_turn.id;
    return private.game_snapshot(v_game.id) || jsonb_build_object('action_error','invalid_clue');
  end if;
  insert into public.clues(game_id,turn_id,player_id,turn_index,clue_text,created_at)
    values(v_game.id,v_turn.id,v_user_id,v_turn.turn_index,v_text,v_now);
  perform private.complete_clue_turn(v_game.id,v_turn.id,'submitted',v_now);
  return private.game_snapshot(v_game.id);
exception when unique_violation then raise exception 'clue_already_submitted' using errcode='P0001';
end;
$$;

revoke all on function public.acknowledge_role(), public.advance_game_if_due(), public.submit_clue(text) from public, anon, authenticated;
grant execute on function public.acknowledge_role(), public.advance_game_if_due(), public.submit_clue(text) to authenticated;

create function private.broadcast_game_changed()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform private.broadcast_room_changed(new.room_id);
  return new;
end;
$$;
revoke all on function private.broadcast_game_changed() from public, anon, authenticated;
create trigger games_broadcast_change after update on public.games
for each row when (old.revision is distinct from new.revision)
execute function private.broadcast_game_changed();
