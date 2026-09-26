alter table public.game_players add column discussion_ready_at timestamptz;
alter table public.games
  add column eliminated_player_id uuid references public.profiles(id) on delete restrict,
  add column resolved_by_random_tie_break boolean not null default false;

create table public.voting_rounds (
  id bigint generated always as identity primary key,
  game_id uuid not null references public.games(id) on delete restrict,
  round_number integer not null check (round_number between 1 and 2),
  status text not null check (status in ('active','completed')),
  started_at timestamptz not null,
  ends_at timestamptz not null,
  completed_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  constraint voting_rounds_game_number_unique unique(game_id,round_number),
  constraint voting_rounds_window_valid check (ends_at>=started_at),
  constraint voting_rounds_completion_valid check (
    (status='active' and completed_at is null) or
    (status='completed' and completed_at is not null)
  )
);
create unique index voting_rounds_one_active_per_game
  on public.voting_rounds(game_id) where status='active';

create table public.voting_round_candidates (
  voting_round_id bigint not null references public.voting_rounds(id) on delete restrict,
  player_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  primary key(voting_round_id,player_id)
);

create table public.votes (
  id bigint generated always as identity primary key,
  voting_round_id bigint not null references public.voting_rounds(id) on delete restrict,
  voter_id uuid not null references public.profiles(id) on delete restrict,
  target_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  constraint votes_voter_unique unique(voting_round_id,voter_id),
  constraint votes_no_self_vote check(voter_id<>target_id)
);

alter table public.voting_rounds enable row level security;
alter table public.voting_rounds force row level security;
alter table public.voting_round_candidates enable row level security;
alter table public.voting_round_candidates force row level security;
alter table public.votes enable row level security;
alter table public.votes force row level security;
revoke all on table public.voting_rounds,public.voting_round_candidates,public.votes from public,anon,authenticated;
revoke all on sequence public.voting_rounds_id_seq,public.votes_id_seq from public,anon,authenticated;

create function private.start_voting_round(
  p_game_id uuid,p_round_number integer,p_candidate_ids uuid[],p_now timestamptz
) returns void language plpgsql security definer set search_path='' as $$
declare v_round_id bigint;
begin
  if p_round_number not between 1 and 2 or cardinality(p_candidate_ids)<1 then
    raise exception 'invalid_voting_round' using errcode='P0001';
  end if;
  insert into public.voting_rounds(game_id,round_number,status,started_at,ends_at)
    values(p_game_id,p_round_number,'active',p_now,p_now+interval '30 seconds')
    returning id into v_round_id;
  insert into public.voting_round_candidates(voting_round_id,player_id)
    select v_round_id,x from unnest(p_candidate_ids) x;
  update public.games set status='voting',phase_started_at=p_now,
    phase_ends_at=p_now+interval '30 seconds',revision=revision+1
    where id=p_game_id;
end;
$$;
revoke all on function private.start_voting_round(uuid,integer,uuid[],timestamptz) from public,anon,authenticated;

create function private.complete_voting_round(p_game_id uuid,p_round_id bigint,p_now timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare v_number integer; v_tied uuid[]; v_eliminated uuid; v_max integer;
begin
  update public.voting_rounds set status='completed',completed_at=p_now
    where id=p_round_id and game_id=p_game_id and status='active'
    returning round_number into strict v_number;
  select max(vote_count) into v_max from (
    select c.player_id,count(v.id)::integer vote_count
    from public.voting_round_candidates c left join public.votes v
      on v.voting_round_id=c.voting_round_id and v.target_id=c.player_id
    where c.voting_round_id=p_round_id group by c.player_id
  ) totals;
  select array_agg(player_id order by player_id) into v_tied from (
    select c.player_id,count(v.id)::integer vote_count
    from public.voting_round_candidates c left join public.votes v
      on v.voting_round_id=c.voting_round_id and v.target_id=c.player_id
    where c.voting_round_id=p_round_id group by c.player_id
  ) totals where vote_count=v_max;
  if cardinality(v_tied)=1 then
    v_eliminated:=v_tied[1];
    update public.games set status='vote_result',phase_started_at=p_now,phase_ends_at=null,
      eliminated_player_id=v_eliminated,resolved_by_random_tie_break=false,revision=revision+1
      where id=p_game_id;
  elsif v_number=1 then
    update public.games set status='vote_result',phase_started_at=p_now,
      phase_ends_at=p_now+interval '5 seconds',eliminated_player_id=null,
      resolved_by_random_tie_break=false,revision=revision+1 where id=p_game_id;
  else
    select x into v_eliminated from unnest(v_tied) x
      order by encode(extensions.gen_random_bytes(16),'hex') limit 1;
    update public.games set status='vote_result',phase_started_at=p_now,phase_ends_at=null,
      eliminated_player_id=v_eliminated,resolved_by_random_tie_break=true,revision=revision+1
      where id=p_game_id;
  end if;
end;
$$;
revoke all on function private.complete_voting_round(uuid,bigint,timestamptz) from public,anon,authenticated;

create or replace function private.game_snapshot(p_game_id uuid)
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object(
    'game_id',g.id,'room_id',g.room_id,'round_number',g.round_number,'status',g.status,
    'phase_started_at',g.phase_started_at,'phase_ends_at',g.phase_ends_at,
    'server_now',clock_timestamp(),'revision',g.revision,
    'participants',coalesce((select jsonb_agg(jsonb_build_object(
      'player_id',gp.player_id,'username',p.username,'avatar_id',p.avatar_id,
      'role_acknowledged',gp.role_acknowledged_at is not null,
      'discussion_ready',gp.discussion_ready_at is not null
    ) order by gp.turn_order) from public.game_players gp join public.profiles p on p.id=gp.player_id
      where gp.game_id=g.id),'[]'::jsonb),
    'turns',coalesce((select jsonb_agg(jsonb_build_object(
      'turn_id',gt.id,'turn_index',gt.turn_index,'player_id',gt.player_id,'status',gt.status,
      'started_at',gt.started_at,'ends_at',gt.ends_at,'completed_at',gt.completed_at,'clue_text',c.clue_text
    ) order by gt.turn_index) from public.game_turns gt left join public.clues c on c.turn_id=gt.id
      where gt.game_id=g.id),'[]'::jsonb),
    'voting',(select case when vr.id is null then null else jsonb_build_object(
      'round_number',vr.round_number,'status',vr.status,'ends_at',vr.ends_at,
      'submitted_vote_count',(select count(*) from public.votes v where v.voting_round_id=vr.id),
      'eligible_voter_count',(select count(*) from public.game_players gp where gp.game_id=g.id),
      'current_user_has_voted',exists(select 1 from public.votes v where v.voting_round_id=vr.id and v.voter_id=auth.uid()),
      'candidates',coalesce((select jsonb_agg(jsonb_build_object(
        'player_id',p.id,'username',p.username,'avatar_id',p.avatar_id
      ) order by p.username,p.id) from public.voting_round_candidates vrc join public.profiles p on p.id=vrc.player_id
        where vrc.voting_round_id=vr.id),'[]'::jsonb),
      'results',case when vr.status='completed' then coalesce((select jsonb_agg(jsonb_build_object(
        'player_id',vrc.player_id,'vote_count',(select count(*) from public.votes v where v.voting_round_id=vr.id and v.target_id=vrc.player_id)
      ) order by vrc.player_id) from public.voting_round_candidates vrc where vrc.voting_round_id=vr.id),'[]'::jsonb) else null end,
      'next_round_required',(vr.status='completed' and vr.round_number=1 and g.eliminated_player_id is null),
      'eliminated_player_id',g.eliminated_player_id,
      'resolved_by_random_tie_break',g.resolved_by_random_tie_break
    ) end from public.voting_rounds vr where vr.game_id=g.id order by vr.round_number desc limit 1)
  ) from public.games g where g.id=p_game_id;
$$;

create function public.set_discussion_ready(p_ready boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user_id uuid:=auth.uid(); v_game public.games; v_now timestamptz:=clock_timestamp(); v_changed boolean;
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode='P0001'; end if;
  if p_ready is null then raise exception 'invalid_ready_state' using errcode='P0001'; end if;
  select g.* into v_game from public.games g join public.game_players gp on gp.game_id=g.id
    where gp.player_id=v_user_id and g.status<>'result' order by g.created_at desc limit 1 for update of g;
  if not found then raise exception 'not_game_participant' using errcode='P0001'; end if;
  if v_game.status<>'discussion' then raise exception 'invalid_game_phase' using errcode='P0001'; end if;
  update public.game_players set discussion_ready_at=case when p_ready then v_now else null end
    where game_id=v_game.id and player_id=v_user_id
      and (discussion_ready_at is not null) is distinct from p_ready;
  v_changed:=found;
  if v_changed then update public.games set revision=revision+1 where id=v_game.id; end if;
  if not exists(select 1 from public.game_players gp where gp.game_id=v_game.id and gp.discussion_ready_at is null) then
    perform private.start_voting_round(v_game.id,1,array(select gp.player_id from public.game_players gp where gp.game_id=v_game.id order by gp.turn_order),v_now);
  end if;
  return private.game_snapshot(v_game.id);
end;
$$;

create function public.submit_vote(p_target_player_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user_id uuid:=auth.uid(); v_game public.games; v_round public.voting_rounds; v_existing uuid; v_now timestamptz:=clock_timestamp();
begin
  if v_user_id is null then raise exception 'authentication_required' using errcode='P0001'; end if;
  select g.* into v_game from public.games g join public.game_players gp on gp.game_id=g.id
    where gp.player_id=v_user_id and g.status<>'result' order by g.created_at desc limit 1 for update of g;
  if not found then raise exception 'not_game_participant' using errcode='P0001'; end if;
  if v_game.status<>'voting' then raise exception 'invalid_game_phase' using errcode='P0001'; end if;
  select vr.* into v_round from public.voting_rounds vr where vr.game_id=v_game.id and vr.status='active' for update;
  if not found then raise exception 'voting_round_not_found' using errcode='P0001'; end if;
  if v_round.ends_at<=v_now then raise exception 'vote_expired' using errcode='P0001'; end if;
  if p_target_player_id=v_user_id then raise exception 'self_vote_not_allowed' using errcode='P0001'; end if;
  if not exists(select 1 from public.voting_round_candidates c where c.voting_round_id=v_round.id and c.player_id=p_target_player_id) then
    raise exception 'invalid_vote_target' using errcode='P0001';
  end if;
  select v.target_id into v_existing from public.votes v where v.voting_round_id=v_round.id and v.voter_id=v_user_id;
  if v_existing is not null then
    if v_existing=p_target_player_id then return private.game_snapshot(v_game.id); end if;
    raise exception 'vote_already_submitted' using errcode='P0001';
  end if;
  insert into public.votes(voting_round_id,voter_id,target_id) values(v_round.id,v_user_id,p_target_player_id);
  update public.games set revision=revision+1 where id=v_game.id;
  if (select count(*) from public.votes v where v.voting_round_id=v_round.id) =
     (select count(*) from public.game_players gp where gp.game_id=v_game.id) then
    perform private.complete_voting_round(v_game.id,v_round.id,v_now);
  end if;
  return private.game_snapshot(v_game.id);
exception when unique_violation then
  select v.target_id into v_existing from public.votes v where v.voting_round_id=v_round.id and v.voter_id=v_user_id;
  if v_existing=p_target_player_id then return private.game_snapshot(v_game.id); end if;
  raise exception 'vote_already_submitted' using errcode='P0001';
end;
$$;

create or replace function public.advance_game_if_due()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user_id uuid:=auth.uid(); v_game public.games; v_turn_id bigint; v_round public.voting_rounds;
  v_now timestamptz:=clock_timestamp(); v_tied uuid[]; v_max integer;
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
  elsif v_game.status='discussion' and v_game.phase_ends_at<=v_now then
    perform private.start_voting_round(v_game.id,1,array(select gp.player_id from public.game_players gp where gp.game_id=v_game.id order by gp.turn_order),v_now);
  elsif v_game.status='voting' then
    select vr.* into v_round from public.voting_rounds vr where vr.game_id=v_game.id and vr.status='active' for update;
    if found and v_round.ends_at<=v_now then perform private.complete_voting_round(v_game.id,v_round.id,v_now); end if;
  elsif v_game.status='vote_result' and v_game.eliminated_player_id is null and v_game.phase_ends_at<=v_now then
    select vr.* into strict v_round from public.voting_rounds vr where vr.game_id=v_game.id and vr.round_number=1 and vr.status='completed';
    select max(vote_count) into v_max from (select c.player_id,count(v.id)::integer vote_count from public.voting_round_candidates c left join public.votes v on v.voting_round_id=c.voting_round_id and v.target_id=c.player_id where c.voting_round_id=v_round.id group by c.player_id) t;
    select array_agg(player_id order by player_id) into v_tied from (select c.player_id,count(v.id)::integer vote_count from public.voting_round_candidates c left join public.votes v on v.voting_round_id=c.voting_round_id and v.target_id=c.player_id where c.voting_round_id=v_round.id group by c.player_id) t where vote_count=v_max;
    perform private.start_voting_round(v_game.id,2,v_tied,v_now);
  end if;
  return private.game_snapshot(v_game.id);
end;
$$;

revoke all on function public.set_discussion_ready(boolean),public.submit_vote(uuid) from public,anon,authenticated;
grant execute on function public.set_discussion_ready(boolean),public.submit_vote(uuid) to authenticated;
