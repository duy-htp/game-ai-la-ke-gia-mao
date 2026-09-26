alter table public.games add column winner_team text check(winner_team in ('normal','impostor')),
  add column result_reason text check(result_reason in ('normal_eliminated','impostor_final_guess_correct','impostor_final_guess_wrong','impostor_final_guess_timeout')),
  add column finished_at timestamptz;
alter table public.profiles add column games_played integer not null default 0 check(games_played>=0),
  add column games_won integer not null default 0 check(games_won>=0),
  add column normal_wins integer not null default 0 check(normal_wins>=0),
  add column impostor_wins integer not null default 0 check(impostor_wins>=0),
  add column correct_votes integer not null default 0 check(correct_votes>=0);

create table public.final_guess_options(
  id uuid primary key default gen_random_uuid(), game_id uuid not null references public.games(id) on delete restrict,
  word_id bigint not null references public.words(id) on delete restrict, display_order integer not null check(display_order between 1 and 4),
  created_at timestamptz not null default clock_timestamp(), unique(game_id,word_id),unique(game_id,display_order));
create table public.final_guesses(
  game_id uuid primary key references public.games(id) on delete restrict,
  player_id uuid not null references public.profiles(id) on delete restrict,
  choice_id uuid not null references public.final_guess_options(id) on delete restrict,
  is_correct boolean not null,
  submitted_at timestamptz not null default clock_timestamp());
create table public.game_rewards(
  id bigint generated always as identity primary key, game_id uuid not null references public.games(id) on delete restrict,
  player_id uuid not null references public.profiles(id) on delete restrict,
  xp_delta integer not null check(xp_delta>=0),coins_delta integer not null check(coins_delta>=0),
  resulting_xp integer,resulting_coins integer,resulting_level integer,
  created_at timestamptz not null default clock_timestamp(),unique(game_id,player_id));

alter table public.final_guess_options enable row level security; alter table public.final_guess_options force row level security;
alter table public.final_guesses enable row level security; alter table public.final_guesses force row level security;
alter table public.game_rewards enable row level security; alter table public.game_rewards force row level security;
revoke all on table public.final_guess_options,public.final_guesses,public.game_rewards from public,anon,authenticated;
revoke all on sequence public.game_rewards_id_seq from public,anon,authenticated;

create function private.create_final_guess(p_game_id uuid,p_now timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare v_keyword bigint;v_category bigint;
begin
  select keyword_id,category_id into strict v_keyword,v_category from public.games where id=p_game_id;
  insert into public.final_guess_options(game_id,word_id,display_order)
  select p_game_id,id,row_number() over(order by encode(extensions.gen_random_bytes(16),'hex'))::integer from (
    select v_keyword id union all
    select id from (select w.id from public.words w where w.is_active and w.id<>v_keyword
      order by (w.category_id=v_category) desc,encode(extensions.gen_random_bytes(16),'hex') limit 3) alternatives
  ) choices;
  if (select count(*) from public.final_guess_options where game_id=p_game_id)<>4 then raise exception 'insufficient_guess_options' using errcode='P0001';end if;
  update public.games set status='final_guess',phase_started_at=p_now,phase_ends_at=p_now+interval '20 seconds',revision=revision+1 where id=p_game_id;
end;$$;
revoke all on function private.create_final_guess(uuid,timestamptz) from public,anon,authenticated;

create function private.resolve_game_result(p_game_id uuid,p_winner text,p_reason text,p_now timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare r record;v_xp integer;v_coins integer;v_correct boolean;v_new_xp integer;v_new_coins integer;v_new_level integer;v_inserted bigint;v_decisive bigint;
begin
  if p_winner not in('normal','impostor') then raise exception 'invalid_winner' using errcode='P0001';end if;
  update public.games set status='result',winner_team=p_winner,result_reason=p_reason,finished_at=p_now,
    phase_started_at=p_now,phase_ends_at=null,revision=revision+1 where id=p_game_id and status<>'result';
  if not found then return;end if;
  select id into v_decisive from public.voting_rounds where game_id=p_game_id and status='completed' order by round_number desc limit 1;
  for r in select gp.player_id,gp.role,g.eliminated_player_id from public.game_players gp join public.games g on g.id=gp.game_id where gp.game_id=p_game_id loop
    v_correct:=exists(select 1 from public.votes v join public.game_players target on target.game_id=p_game_id and target.player_id=v.target_id
      where v.voting_round_id=v_decisive and v.voter_id=r.player_id and target.role='impostor');
    v_xp:=0;
    if r.role='normal' then
      if (select role from public.game_players where game_id=p_game_id and player_id=r.eliminated_player_id)='impostor' then v_xp:=v_xp+100;end if;
      if v_correct then v_xp:=v_xp+30;end if;
      if p_winner='normal' then v_xp:=v_xp+50;end if;
    elsif p_reason='normal_eliminated' then v_xp:=150;
    elsif p_reason='impostor_final_guess_correct' and r.player_id=r.eliminated_player_id then v_xp:=120;end if;
    v_coins:=10+case when r.role=p_winner then 10 else 0 end;
    insert into public.game_rewards(game_id,player_id,xp_delta,coins_delta) values(p_game_id,r.player_id,v_xp,v_coins)
      on conflict(game_id,player_id) do nothing returning id into v_inserted;
    if v_inserted is not null then
      update public.profiles set xp=xp+v_xp,coins=coins+v_coins,level=((xp+v_xp)/500)+1,
        games_played=games_played+1,games_won=games_won+case when r.role=p_winner then 1 else 0 end,
        normal_wins=normal_wins+case when r.role='normal' and p_winner='normal' then 1 else 0 end,
        impostor_wins=impostor_wins+case when r.role='impostor' and p_winner='impostor' then 1 else 0 end,
        correct_votes=correct_votes+case when v_correct then 1 else 0 end
        where id=r.player_id returning xp,coins,level into v_new_xp,v_new_coins,v_new_level;
      update public.game_rewards set resulting_xp=v_new_xp,resulting_coins=v_new_coins,resulting_level=v_new_level where id=v_inserted;
    end if;
    v_inserted:=null;
  end loop;
end;$$;
revoke all on function private.resolve_game_result(uuid,text,text,timestamptz) from public,anon,authenticated;

create or replace function private.complete_voting_round(p_game_id uuid,p_round_id bigint,p_now timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare v_number integer;v_tied uuid[];v_eliminated uuid;v_max integer;
begin
 update public.voting_rounds set status='completed',completed_at=p_now where id=p_round_id and game_id=p_game_id and status='active' returning round_number into strict v_number;
 select max(vote_count) into v_max from(select c.player_id,count(v.id)::integer vote_count from public.voting_round_candidates c left join public.votes v on v.voting_round_id=c.voting_round_id and v.target_id=c.player_id where c.voting_round_id=p_round_id group by c.player_id)t;
 select array_agg(player_id order by player_id) into v_tied from(select c.player_id,count(v.id)::integer vote_count from public.voting_round_candidates c left join public.votes v on v.voting_round_id=c.voting_round_id and v.target_id=c.player_id where c.voting_round_id=p_round_id group by c.player_id)t where vote_count=v_max;
 if cardinality(v_tied)=1 then v_eliminated:=v_tied[1];
 elsif v_number=2 then select x into v_eliminated from unnest(v_tied)x order by encode(extensions.gen_random_bytes(16),'hex') limit 1;end if;
 update public.games set status='vote_result',phase_started_at=p_now,phase_ends_at=p_now+interval '5 seconds',
  eliminated_player_id=v_eliminated,resolved_by_random_tie_break=(v_number=2 and cardinality(v_tied)>1),revision=revision+1 where id=p_game_id;
end;$$;

create or replace function private.game_snapshot(p_game_id uuid)
returns jsonb language sql stable set search_path='' as $$
select jsonb_build_object('game_id',g.id,'room_id',g.room_id,'round_number',g.round_number,'status',g.status,
 'phase_started_at',g.phase_started_at,'phase_ends_at',g.phase_ends_at,'server_now',clock_timestamp(),'revision',g.revision,
 'participants',coalesce((select jsonb_agg(jsonb_build_object('player_id',gp.player_id,'username',p.username,'avatar_id',p.avatar_id,
  'role_acknowledged',gp.role_acknowledged_at is not null,'discussion_ready',gp.discussion_ready_at is not null,
  'role',case when g.status='result' then gp.role end)order by gp.turn_order)from public.game_players gp join public.profiles p on p.id=gp.player_id where gp.game_id=g.id),'[]'::jsonb),
 'turns',coalesce((select jsonb_agg(jsonb_build_object('turn_id',gt.id,'turn_index',gt.turn_index,'player_id',gt.player_id,'status',gt.status,'started_at',gt.started_at,'ends_at',gt.ends_at,'completed_at',gt.completed_at,'clue_text',c.clue_text)order by gt.turn_index)from public.game_turns gt left join public.clues c on c.turn_id=gt.id where gt.game_id=g.id),'[]'::jsonb),
 'voting',(select case when vr.id is null then null else jsonb_build_object('round_number',vr.round_number,'status',vr.status,'ends_at',vr.ends_at,
  'submitted_vote_count',(select count(*)from public.votes v where v.voting_round_id=vr.id),'eligible_voter_count',(select count(*)from public.game_players gp where gp.game_id=g.id),
  'current_user_has_voted',exists(select 1 from public.votes v where v.voting_round_id=vr.id and v.voter_id=auth.uid()),
  'candidates',coalesce((select jsonb_agg(jsonb_build_object('player_id',p.id,'username',p.username,'avatar_id',p.avatar_id)order by p.username,p.id)from public.voting_round_candidates x join public.profiles p on p.id=x.player_id where x.voting_round_id=vr.id),'[]'::jsonb),
  'results',case when vr.status='completed' then coalesce((select jsonb_agg(jsonb_build_object('player_id',x.player_id,'vote_count',(select count(*)from public.votes v where v.voting_round_id=vr.id and v.target_id=x.player_id))order by x.player_id)from public.voting_round_candidates x where x.voting_round_id=vr.id),'[]'::jsonb)else null end,
  'next_round_required',(vr.status='completed' and vr.round_number=1 and g.eliminated_player_id is null),'eliminated_player_id',g.eliminated_player_id,'resolved_by_random_tie_break',g.resolved_by_random_tie_break)end from public.voting_rounds vr where vr.game_id=g.id order by vr.round_number desc limit 1),
 'final_guess',case when g.status in('final_guess','result') then jsonb_build_object('guessing_player_id',g.eliminated_player_id,
  'choices',case when g.status='final_guess' and auth.uid()=g.eliminated_player_id then coalesce((select jsonb_agg(jsonb_build_object('choice_id',o.id,'word_vi',w.word_vi,'word_en',w.word_en)order by o.display_order)from public.final_guess_options o join public.words w on w.id=o.word_id where o.game_id=g.id),'[]'::jsonb)else '[]'::jsonb end,
  'has_submitted',exists(select 1 from public.final_guesses fg where fg.game_id=g.id),
  'selected_choice_id',case when g.status='result' then(select choice_id from public.final_guesses where game_id=g.id)end,
  'is_correct',case when g.status='result' then(select is_correct from public.final_guesses where game_id=g.id)end,
  'timed_out',case when g.status='result' then g.result_reason='impostor_final_guess_timeout' end)end,
 'result',case when g.status='result' then jsonb_build_object('winner_team',g.winner_team,'reason',g.result_reason,'keyword_vi',w.word_vi,'keyword_en',w.word_en,
  'eliminated_player_id',g.eliminated_player_id,'finished_at',g.finished_at,'reward',(select jsonb_build_object('xp_gained',r.xp_delta,'coins_gained',r.coins_delta,'new_xp',r.resulting_xp,'new_coins',r.resulting_coins,'new_level',r.resulting_level)from public.game_rewards r where r.game_id=g.id and r.player_id=auth.uid()))end
 )from public.games g join public.words w on w.id=g.keyword_id where g.id=p_game_id;$$;

create or replace function public.get_current_game()returns jsonb language plpgsql security definer stable set search_path='' as $$
declare v_user uuid:=auth.uid();v_game uuid;
begin if v_user is null then raise exception 'authentication_required' using errcode='P0001';end if;
 select gp.game_id into v_game from public.game_players gp join public.games g on g.id=gp.game_id join public.rooms r on r.id=g.room_id
 where gp.player_id=v_user and r.status='in_game' order by g.created_at desc limit 1;
 if v_game is null then return null;end if;return private.game_snapshot(v_game);end;$$;

create function public.submit_final_guess(p_choice_id uuid)returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_game public.games;v_existing uuid;v_correct boolean;v_now timestamptz:=clock_timestamp();
begin if v_user is null then raise exception 'authentication_required' using errcode='P0001';end if;
 select g.* into v_game from public.games g join public.game_players gp on gp.game_id=g.id where gp.player_id=v_user and g.status in('final_guess','result') order by g.created_at desc limit 1 for update of g;
 if not found then raise exception 'not_game_participant' using errcode='P0001';end if;
 select choice_id into v_existing from public.final_guesses where game_id=v_game.id;
 if v_existing is not null then if v_existing=p_choice_id then return private.game_snapshot(v_game.id);end if;raise exception 'final_guess_already_submitted' using errcode='P0001';end if;
 if v_game.status<>'final_guess' then raise exception 'invalid_game_phase' using errcode='P0001';end if;
 if v_user<>v_game.eliminated_player_id then raise exception 'not_guessing_player' using errcode='P0001';end if;
 if v_game.phase_ends_at<=v_now then raise exception 'final_guess_expired' using errcode='P0001';end if;
 select(o.word_id=v_game.keyword_id)into v_correct from public.final_guess_options o where o.game_id=v_game.id and o.id=p_choice_id;
 if v_correct is null then raise exception 'invalid_guess_choice' using errcode='P0001';end if;
 insert into public.final_guesses(game_id,player_id,choice_id,is_correct)values(v_game.id,v_user,p_choice_id,v_correct);
 perform private.resolve_game_result(v_game.id,case when v_correct then'impostor'else'normal'end,case when v_correct then'impostor_final_guess_correct'else'impostor_final_guess_wrong'end,v_now);
 return private.game_snapshot(v_game.id);end;$$;

create or replace function public.advance_game_if_due()returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_game public.games;v_turn bigint;v_round public.voting_rounds;v_now timestamptz:=clock_timestamp();v_tied uuid[];v_max integer;v_role text;
begin if v_user is null then raise exception 'authentication_required' using errcode='P0001';end if;
 select g.* into v_game from public.games g join public.game_players gp on gp.game_id=g.id where gp.player_id=v_user and g.status<>'result' order by g.created_at desc limit 1 for update of g;
 if not found then select g.* into v_game from public.games g join public.game_players gp on gp.game_id=g.id where gp.player_id=v_user and g.status='result' order by g.created_at desc limit 1; if not found then raise exception 'not_game_participant' using errcode='P0001';end if;return private.game_snapshot(v_game.id);end if;
 if v_game.status='role_reveal'and v_game.phase_ends_at<=v_now then perform private.start_clue_phase(v_game.id,v_now);
 elsif v_game.status='clue'then select id into v_turn from public.game_turns where game_id=v_game.id and status='active'and ends_at<=v_now for update;if v_turn is not null then perform private.complete_clue_turn(v_game.id,v_turn,'timed_out',v_now);end if;
 elsif v_game.status='discussion'and v_game.phase_ends_at<=v_now then perform private.start_voting_round(v_game.id,1,array(select player_id from public.game_players where game_id=v_game.id order by turn_order),v_now);
 elsif v_game.status='voting'then select*into v_round from public.voting_rounds where game_id=v_game.id and status='active'for update;if found and v_round.ends_at<=v_now then perform private.complete_voting_round(v_game.id,v_round.id,v_now);end if;
 elsif v_game.status='vote_result'and v_game.phase_ends_at<=v_now then
  if v_game.eliminated_player_id is null then select*into strict v_round from public.voting_rounds where game_id=v_game.id and round_number=1;
   select max(n)into v_max from(select c.player_id,count(v.id)::integer n from public.voting_round_candidates c left join public.votes v on v.voting_round_id=c.voting_round_id and v.target_id=c.player_id where c.voting_round_id=v_round.id group by c.player_id)t;
   select array_agg(player_id order by player_id)into v_tied from(select c.player_id,count(v.id)::integer n from public.voting_round_candidates c left join public.votes v on v.voting_round_id=c.voting_round_id and v.target_id=c.player_id where c.voting_round_id=v_round.id group by c.player_id)t where n=v_max;perform private.start_voting_round(v_game.id,2,v_tied,v_now);
  else select role into strict v_role from public.game_players where game_id=v_game.id and player_id=v_game.eliminated_player_id;
   if v_role='normal'then perform private.resolve_game_result(v_game.id,'impostor','normal_eliminated',v_now);else perform private.create_final_guess(v_game.id,v_now);end if;end if;
 elsif v_game.status='final_guess'and v_game.phase_ends_at<=v_now then perform private.resolve_game_result(v_game.id,'normal','impostor_final_guess_timeout',v_now);end if;
 return private.game_snapshot(v_game.id);end;$$;

create function public.play_again()returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_room public.rooms;v_game uuid;
begin if v_user is null then raise exception'authentication_required'using errcode='P0001';end if;
 select r.* into v_room from public.room_players rp join public.rooms r on r.id=rp.room_id where rp.player_id=v_user and rp.left_at is null order by rp.joined_at desc limit 1 for update of r;
 if not found then raise exception'not_room_member'using errcode='P0001';end if;if v_room.host_id<>v_user then raise exception'not_host'using errcode='P0001';end if;
 if v_room.status='waiting'then return private.room_snapshot(v_room.id);end if;
 select id into v_game from public.games where room_id=v_room.id and status='result'order by round_number desc limit 1;
 if v_game is null then raise exception'invalid_game_phase'using errcode='P0001';end if;
 update public.room_players set is_ready=false where room_id=v_room.id and left_at is null and player_id<>v_user;
 update public.rooms set status='waiting',revision=revision+1 where id=v_room.id;return private.room_snapshot(v_room.id);end;$$;

create or replace function public.leave_room()returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_room public.rooms;v_next uuid;
begin if v_user is null then raise exception'authentication_required'using errcode='P0001';end if;perform pg_advisory_xact_lock(hashtextextended(v_user::text,0));
 select r.* into v_room from public.room_players rp join public.rooms r on r.id=rp.room_id where rp.player_id=v_user and rp.left_at is null for update of r;if not found then return null;end if;
 if v_room.status='in_game'and not exists(select 1 from public.games where room_id=v_room.id and status='result')then raise exception'room_in_game'using errcode='P0001';end if;
 update public.room_players set left_at=clock_timestamp()where room_id=v_room.id and player_id=v_user and left_at is null;
 if v_room.host_id=v_user then select player_id into v_next from public.room_players where room_id=v_room.id and left_at is null order by joined_at,seat,player_id limit 1;
  if v_next is null then update public.rooms set status='closed',host_id=null where id=v_room.id;else update public.rooms set host_id=v_next where id=v_room.id;end if;end if;return null;end;$$;

revoke all on function public.submit_final_guess(uuid),public.play_again()from public,anon,authenticated;
grant execute on function public.submit_final_guess(uuid),public.play_again()to authenticated;
