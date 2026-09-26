begin;
select plan(36);
insert into auth.users(id,email) select id,s||'@vote.test' from (values
 ('71000000-0000-4000-8000-000000000001'::uuid,'one'),
 ('71000000-0000-4000-8000-000000000002'::uuid,'two'),
 ('71000000-0000-4000-8000-000000000003'::uuid,'three'),
 ('71000000-0000-4000-8000-000000000004'::uuid,'out')) u(id,s);
insert into public.profiles(id,username,avatar_id) values
 ('71000000-0000-4000-8000-000000000001','Vote One','avatar_01'),
 ('71000000-0000-4000-8000-000000000002','Vote Two','avatar_02'),
 ('71000000-0000-4000-8000-000000000003','Vote Three','avatar_03'),
 ('71000000-0000-4000-8000-000000000004','Vote Out','avatar_04');
insert into public.rooms(id,code,created_by,host_id,game_type,status,max_players,create_request_id)
 values('71000000-0000-4000-8000-000000000010','ABC234','71000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000001','impostor','in_game',3,'71000000-0000-4000-8000-000000000011');
insert into public.room_players(room_id,player_id,seat,is_ready) values
 ('71000000-0000-4000-8000-000000000010','71000000-0000-4000-8000-000000000001',1,true),
 ('71000000-0000-4000-8000-000000000010','71000000-0000-4000-8000-000000000002',2,true),
 ('71000000-0000-4000-8000-000000000010','71000000-0000-4000-8000-000000000003',3,true);
insert into public.games(id,room_id,round_number,status,category_id,keyword_id,phase_started_at,phase_ends_at,started_by,start_request_id,impostor_count,clue_seconds,discussion_seconds)
 select '71000000-0000-4000-8000-000000000020','71000000-0000-4000-8000-000000000010',1,'discussion',w.category_id,w.id,clock_timestamp(),clock_timestamp()+interval '60 seconds','71000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000021',1,15,60 from public.words w limit 1;
insert into public.game_players(game_id,player_id,role,turn_order) values
 ('71000000-0000-4000-8000-000000000020','71000000-0000-4000-8000-000000000001','normal',1),
 ('71000000-0000-4000-8000-000000000020','71000000-0000-4000-8000-000000000002','normal',2),
 ('71000000-0000-4000-8000-000000000020','71000000-0000-4000-8000-000000000003','impostor',3);

set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000004',true);
select throws_ok($$select public.set_discussion_ready(true)$$,'P0001','not_game_participant','Outsider cannot ready');
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000001',true);
select ok((public.set_discussion_ready(true)->'participants' @> '[{"player_id":"71000000-0000-4000-8000-000000000001","discussion_ready":true}]'),'Ready true is public safely');
select is((public.set_discussion_ready(true)->>'revision')::integer,2,'Ready true retry is idempotent');
select is((public.set_discussion_ready(false)->'participants'->0->>'discussion_ready')::boolean,false,'Ready false works');
select is((public.set_discussion_ready(false)->>'revision')::integer,3,'Ready false retry is idempotent');
do $$ begin perform public.set_discussion_ready(true); end $$;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000002',true);
do $$ begin perform public.set_discussion_ready(true); end $$;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000003',true);
select is(public.set_discussion_ready(true)->>'status','voting','All ready starts voting');
set local role postgres;
select is((select count(*)::integer from public.voting_rounds),1,'Exactly one voting round created');
select is((select count(*)::integer from public.voting_round_candidates),3,'Round one includes all candidates');
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000001',true);
select ok((public.get_current_game()->'voting'->'results')='null'::jsonb,'Active voting hides totals');
select ok(not (public.get_current_game()->'voting' ?| array['votes','ballots','target_id']),'Snapshot contains no ballots');
select throws_ok($$select public.submit_vote('71000000-0000-4000-8000-000000000001')$$,'P0001','self_vote_not_allowed','Self vote rejected');
select throws_ok($$select public.submit_vote('71000000-0000-4000-8000-000000000004')$$,'P0001','invalid_vote_target','Outsider target rejected');
select is((public.submit_vote('71000000-0000-4000-8000-000000000002')->'voting'->>'current_user_has_voted')::boolean,true,'Valid vote accepted');
select lives_ok($$select public.submit_vote('71000000-0000-4000-8000-000000000002')$$,'Same-target retry succeeds');
select throws_ok($$select public.submit_vote('71000000-0000-4000-8000-000000000003')$$,'P0001','vote_already_submitted','Different-target retry rejected');
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000002',true);
do $$ begin perform public.submit_vote('71000000-0000-4000-8000-000000000001'); end $$;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000003',true);
select is(public.submit_vote('71000000-0000-4000-8000-000000000002')->>'status','vote_result','All votes complete early');
set local role postgres;
select is((select eliminated_player_id from public.games),'71000000-0000-4000-8000-000000000002'::uuid,'Unique highest is eliminated');
select is((select count(*)::integer from public.votes),3,'One immutable vote per voter');
set local role authenticated;
select ok((public.get_current_game()->'voting'->'results') is not null,'Completed result exposes aggregates');
select ok(not (public.get_current_game()::text like '%voter_id%'),'Completed snapshot never exposes voter mapping');
select throws_ok($$insert into public.votes(voting_round_id,voter_id,target_id) values(1,auth.uid(),'71000000-0000-4000-8000-000000000001')$$,'42501','permission denied for table votes','Direct vote insert denied');
select throws_ok($$update public.votes set target_id='71000000-0000-4000-8000-000000000003'$$,'42501','permission denied for table votes','Direct vote update denied');
select throws_ok($$delete from public.votes$$,'42501','permission denied for table votes','Direct vote delete denied');

set local role postgres;
delete from public.votes; delete from public.voting_round_candidates; delete from public.voting_rounds;
update public.games set status='discussion',phase_started_at=clock_timestamp()-interval '61 seconds',phase_ends_at=clock_timestamp()-interval '1 second',eliminated_player_id=null,resolved_by_random_tie_break=false;
update public.game_players set discussion_ready_at=null;
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000001',true);
select is(public.advance_game_if_due()->>'status','voting','Discussion deadline starts voting');
set local role postgres;
select is((select count(*)::integer from public.voting_rounds),1,'Deadline creates one round');
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000001',true);
do $$ begin perform public.submit_vote('71000000-0000-4000-8000-000000000002'); end $$;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000002',true);
do $$ begin perform public.submit_vote('71000000-0000-4000-8000-000000000001'); end $$;
set local role postgres;
update public.voting_rounds set started_at=clock_timestamp()-interval '31 seconds',ends_at=clock_timestamp()-interval '1 second' where status='active';
update public.games set phase_started_at=clock_timestamp()-interval '31 seconds',phase_ends_at=clock_timestamp()-interval '1 second';
set local role authenticated;
select is(public.advance_game_if_due()->>'status','vote_result','Deadline completes with abstention');
select is((public.get_current_game()->'voting'->>'next_round_required')::boolean,true,'First-round tie requests revote');
set local role postgres;
select is((select count(*)::integer from public.votes),2,'Missing voter remains abstention');
update public.games set phase_started_at=clock_timestamp()-interval '6 seconds',phase_ends_at=clock_timestamp()-interval '1 second';
set local role authenticated;
select is(public.advance_game_if_due()->>'status','voting','Tie display deadline starts revote');
set local role postgres;
select is((select count(*)::integer from public.voting_rounds),2,'Exactly two voting rounds');
select is((select count(*)::integer from public.voting_round_candidates c join public.voting_rounds r on r.id=c.voting_round_id where r.round_number=2),2,'Revote candidates contain tied leaders only');
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000003',true);
select throws_ok($$select public.submit_vote('71000000-0000-4000-8000-000000000003')$$,'P0001','self_vote_not_allowed','Revote self vote rejected');
select throws_ok($$select public.submit_vote('71000000-0000-4000-8000-000000000004')$$,'P0001','invalid_vote_target','Non-candidate revote target rejected');
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000001',true);
do $$ begin perform public.submit_vote('71000000-0000-4000-8000-000000000002'); end $$;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000002',true);
do $$ begin perform public.submit_vote('71000000-0000-4000-8000-000000000001'); end $$;
set local role postgres;
update public.voting_rounds set started_at=clock_timestamp()-interval '31 seconds',ends_at=clock_timestamp()-interval '1 second' where status='active';
update public.games set phase_started_at=clock_timestamp()-interval '31 seconds',phase_ends_at=clock_timestamp()-interval '1 second';
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000003',true);
select is(public.advance_game_if_due()->>'status','vote_result','Second-round tie ends in result');
set local role postgres;
select ok((select resolved_by_random_tie_break and eliminated_player_id is not null from public.games),'Second tie securely random-resolves');
select is((select count(*)::integer from public.voting_rounds),2,'No third round exists');
select * from finish();
rollback;
