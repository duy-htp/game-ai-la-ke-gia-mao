begin;
select plan(44);
insert into auth.users(id,email)select id,s||'@result.test'from(values
('81000000-0000-4000-8000-000000000001'::uuid,'one'),('81000000-0000-4000-8000-000000000002'::uuid,'two'),('81000000-0000-4000-8000-000000000003'::uuid,'three'),('81000000-0000-4000-8000-000000000004'::uuid,'out'))u(id,s);
insert into public.profiles(id,username,avatar_id)values
('81000000-0000-4000-8000-000000000001','Result One','avatar_01'),('81000000-0000-4000-8000-000000000002','Result Two','avatar_02'),('81000000-0000-4000-8000-000000000003','Result Three','avatar_03'),('81000000-0000-4000-8000-000000000004','Result Out','avatar_04');
insert into public.rooms(id,code,created_by,host_id,game_type,status,max_players,create_request_id,clue_seconds,discussion_seconds)
values('81000000-0000-4000-8000-000000000010','ABC236','81000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000001','impostor','in_game',6,'81000000-0000-4000-8000-000000000011',15,60);
insert into public.room_players(room_id,player_id,seat,is_ready)values
('81000000-0000-4000-8000-000000000010','81000000-0000-4000-8000-000000000001',1,true),('81000000-0000-4000-8000-000000000010','81000000-0000-4000-8000-000000000002',2,true),('81000000-0000-4000-8000-000000000010','81000000-0000-4000-8000-000000000003',3,true);
create function pg_temp.make_result_game(p_game uuid,p_round integer,p_eliminated uuid)returns void language plpgsql as $$declare v_word bigint;v_cat bigint;v_vr bigint;begin
 select id,category_id into v_word,v_cat from public.words where word_vi='Dưa hấu';
 insert into public.games(id,room_id,round_number,status,category_id,keyword_id,phase_started_at,phase_ends_at,started_by,start_request_id,impostor_count,clue_seconds,discussion_seconds,eliminated_player_id)
 values(p_game,'81000000-0000-4000-8000-000000000010',p_round,'vote_result',v_cat,v_word,clock_timestamp()-interval'6 seconds',clock_timestamp()-interval'1 second','81000000-0000-4000-8000-000000000001',gen_random_uuid(),1,15,60,p_eliminated);
 insert into public.game_players(game_id,player_id,role,turn_order)values(p_game,'81000000-0000-4000-8000-000000000001','normal',1),(p_game,'81000000-0000-4000-8000-000000000002','normal',2),(p_game,'81000000-0000-4000-8000-000000000003','impostor',3);
 insert into public.voting_rounds(game_id,round_number,status,started_at,ends_at,completed_at)values(p_game,1,'completed',clock_timestamp()-interval'40 seconds',clock_timestamp()-interval'10 seconds',clock_timestamp()-interval'9 seconds')returning id into v_vr;
 insert into public.voting_round_candidates(voting_round_id,player_id)values(v_vr,'81000000-0000-4000-8000-000000000001'),(v_vr,'81000000-0000-4000-8000-000000000002'),(v_vr,'81000000-0000-4000-8000-000000000003');
 insert into public.votes(voting_round_id,voter_id,target_id)values(v_vr,'81000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000003'),(v_vr,'81000000-0000-4000-8000-000000000002',p_eliminated), (v_vr,'81000000-0000-4000-8000-000000000003',case when p_eliminated='81000000-0000-4000-8000-000000000003'then'81000000-0000-4000-8000-000000000001'::uuid else p_eliminated end);
end$$;

select pg_temp.make_result_game('81000000-0000-4000-8000-000000000020',1,'81000000-0000-4000-8000-000000000001');
set local role authenticated;select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select is(public.advance_game_if_due()->>'status','result','Normal eliminated resolves directly');
select is(public.get_current_game()->'result'->>'winner_team','impostor','Impostor team wins escape');
select is(public.get_current_game()->'result'->>'reason','normal_eliminated','Escape reason persisted');
select ok(public.get_current_game()->'result' ?& array['keyword_vi','keyword_en','reward'],'Result reveals keyword and own reward');
select is((public.get_current_game()->'participants'->0->>'role'),'normal','Roles reveal only at result');
set local role postgres;
select is((select count(*)::integer from public.game_rewards where game_id='81000000-0000-4000-8000-000000000020'),3,'One reward row per participant');
select is((select xp_delta from public.game_rewards where game_id='81000000-0000-4000-8000-000000000020'and player_id='81000000-0000-4000-8000-000000000003'),150,'Impostor escape awards 150 XP');
select is((select coins_delta from public.game_rewards where game_id='81000000-0000-4000-8000-000000000020'and player_id='81000000-0000-4000-8000-000000000003'),20,'Winning impostor receives 20 coins');
select is((select coins_delta from public.game_rewards where game_id='81000000-0000-4000-8000-000000000020'and player_id='81000000-0000-4000-8000-000000000001'),10,'Losing normal receives 10 coins');
select is((select xp_delta from public.game_rewards where game_id='81000000-0000-4000-8000-000000000020'and player_id='81000000-0000-4000-8000-000000000001'),30,'Decisive correct vote awards 30 XP');
select is((select games_played from public.profiles where id='81000000-0000-4000-8000-000000000003'),1,'Stats games played increments');
select is((select impostor_wins from public.profiles where id='81000000-0000-4000-8000-000000000003'),1,'Impostor win stat increments');
set local role authenticated;select lives_ok($$select public.advance_game_if_due()$$,'Result retry safe');
set local role postgres;select is((select count(*)::integer from public.game_rewards where game_id='81000000-0000-4000-8000-000000000020'),3,'Result retry does not duplicate rewards');

select pg_temp.make_result_game('81000000-0000-4000-8000-000000000030',2,'81000000-0000-4000-8000-000000000003');
set local role authenticated;select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select is(public.advance_game_if_due()->>'status','final_guess','Impostor eliminated enters Final Guess');
select is(jsonb_array_length(public.get_current_game()->'final_guess'->'choices'),0,'Normal receives no actionable choices');
set local role postgres;
select is((select count(*)::integer from public.final_guess_options where game_id='81000000-0000-4000-8000-000000000030'),4,'Exactly four options persisted');
select is((select count(distinct word_id)::integer from public.final_guess_options where game_id='81000000-0000-4000-8000-000000000030'),4,'Options have no duplicate concepts');
select is((select count(*)::integer from public.final_guess_options o join public.games g on g.id=o.game_id where o.game_id='81000000-0000-4000-8000-000000000030'and o.word_id=g.keyword_id),1,'Exactly one option is correct');
select is((select count(*)::integer from public.final_guess_options o join public.words w on w.id=o.word_id join public.games g on g.id=o.game_id where o.game_id='81000000-0000-4000-8000-000000000030'and w.category_id=g.category_id),4,'All alternatives prefer the available same category');
create temporary table guesses as select (max(o.id::text)filter(where o.word_id=g.keyword_id))::uuid correct,(max(o.id::text)filter(where o.word_id<>g.keyword_id))::uuid wrong from public.final_guess_options o join public.games g on g.id=o.game_id where o.game_id='81000000-0000-4000-8000-000000000030';grant select on guesses to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000004',true);
select is(public.get_current_game(),null,'Outsider cannot inspect Final Guess');
select throws_ok($$select public.submit_final_guess((select wrong from guesses))$$,'P0001','not_game_participant','Outsider cannot guess');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.submit_final_guess((select wrong from guesses))$$,'P0001','not_guessing_player','Normal cannot submit guess');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);
select is(jsonb_array_length(public.get_current_game()->'final_guess'->'choices'),4,'Eliminated impostor receives four opaque choices');
select is(public.submit_final_guess((select wrong from guesses))->'result'->>'winner_team','normal','Wrong guess gives normals win');
select lives_ok($$select public.submit_final_guess((select wrong from guesses))$$,'Same guess retry is safe');
select throws_ok($$select public.submit_final_guess((select correct from guesses))$$,'P0001','final_guess_already_submitted','Different second guess rejected');
set local role postgres;
select is((select xp_delta from public.game_rewards where game_id='81000000-0000-4000-8000-000000000030'and player_id='81000000-0000-4000-8000-000000000001'),180,'Normal catch+correct vote+win awards 180 XP');
select is((select coins_delta from public.game_rewards where game_id='81000000-0000-4000-8000-000000000030'and player_id='81000000-0000-4000-8000-000000000001'),20,'Winning normal receives 20 coins');
select ok((select level=(xp/500)+1 from public.profiles where id='81000000-0000-4000-8000-000000000001'),'Level formula recomputed');

select pg_temp.make_result_game('81000000-0000-4000-8000-000000000040',3,'81000000-0000-4000-8000-000000000003');
set local role authenticated;select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);do $$begin perform public.advance_game_if_due();end$$;
set local role postgres;create temporary table correct3 as select o.id from public.final_guess_options o join public.games g on g.id=o.game_id and g.keyword_id=o.word_id where o.game_id='81000000-0000-4000-8000-000000000040';grant select on correct3 to authenticated;
set local role authenticated;select is(public.submit_final_guess((select id from correct3))->'result'->>'reason','impostor_final_guess_correct','Correct guess reason persisted');
set local role postgres;select is((select xp_delta from public.game_rewards where game_id='81000000-0000-4000-8000-000000000040'and player_id='81000000-0000-4000-8000-000000000003'),120,'Guessing impostor receives 120 XP');

select pg_temp.make_result_game('81000000-0000-4000-8000-000000000050',4,'81000000-0000-4000-8000-000000000003');
set local role authenticated;do $$begin perform public.advance_game_if_due();end$$;set local role postgres;update public.games set phase_started_at=clock_timestamp()-interval'21 seconds',phase_ends_at=clock_timestamp()-interval'1 second'where id='81000000-0000-4000-8000-000000000050';
set local role authenticated;select is(public.advance_game_if_due()->'result'->>'reason','impostor_final_guess_timeout','Timeout gives normal result');
set local role postgres;select is((select count(*)::integer from public.final_guesses where game_id='81000000-0000-4000-8000-000000000050'),0,'Timeout stores no fake guess');

select pg_temp.make_result_game('81000000-0000-4000-8000-000000000060',5,'81000000-0000-4000-8000-000000000003');
update public.games set impostor_count=2 where id='81000000-0000-4000-8000-000000000060';
update public.game_players set role='impostor' where game_id='81000000-0000-4000-8000-000000000060'and player_id='81000000-0000-4000-8000-000000000002';
set local role authenticated;select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);do $$begin perform public.advance_game_if_due();end$$;
set local role postgres;create temporary table correct5 as select o.id from public.final_guess_options o join public.games g on g.id=o.game_id and g.keyword_id=o.word_id where o.game_id='81000000-0000-4000-8000-000000000060';grant select on correct5 to authenticated;
set local role authenticated;select is(public.submit_final_guess((select id from correct5))->'result'->>'winner_team','impostor','Two-impostor game ends with impostor team win');
set local role postgres;
select is((select result_reason from public.games where id='81000000-0000-4000-8000-000000000060'),'impostor_final_guess_correct','Two-impostor winner reason persisted');
select is((select xp_delta from public.game_rewards where game_id='81000000-0000-4000-8000-000000000060'and player_id='81000000-0000-4000-8000-000000000003'),120,'Eliminated guessing impostor receives 120 XP');
select is((select xp_delta from public.game_rewards where game_id='81000000-0000-4000-8000-000000000060'and player_id='81000000-0000-4000-8000-000000000002'),0,'Non-guessing impostor receives no guess XP');
set local role authenticated;select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000002',true);select throws_ok($$select public.play_again()$$,'P0001','not_host','Only host can Play Again');
select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);select is(public.play_again()->>'status','waiting','Host returns room to Lobby');
select is(public.play_again()->>'status','waiting','Play Again retry idempotent');
set local role postgres;select is((select count(*)::integer from public.games where room_id='81000000-0000-4000-8000-000000000010'),5,'Game history preserved');
select ok((select not is_ready from public.room_players where room_id='81000000-0000-4000-8000-000000000010'and player_id='81000000-0000-4000-8000-000000000002'),'Non-host readiness reset');
set local role authenticated;select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000002',true);do $$begin perform public.set_ready(true);end$$;select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000003',true);do $$begin perform public.set_ready(true);end$$;select set_config('request.jwt.claim.sub','81000000-0000-4000-8000-000000000001',true);
select is((public.start_game('81000000-0000-4000-8000-000000000099')->>'round_number')::integer,6,'Next game increments round number');
select * from finish();rollback;
