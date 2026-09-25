begin;
select plan(32);

insert into auth.users(id,email) select id, suffix||'@clue.test' from (values
 ('61000000-0000-4000-8000-000000000001'::uuid,'host'),
 ('61000000-0000-4000-8000-000000000002'::uuid,'two'),
 ('61000000-0000-4000-8000-000000000003'::uuid,'three'),
 ('61000000-0000-4000-8000-000000000004'::uuid,'out')
) u(id,suffix);
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000001',true);
do $$ begin perform public.complete_profile('Clue Host','avatar_01'); perform public.create_room('impostor',6,'61000000-0000-4000-8000-000000000011'); end $$;
set local role postgres;
create temporary table cv as select id room_id,code from public.rooms where created_by='61000000-0000-4000-8000-000000000001';
grant select on cv to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000002',true);
do $$ begin perform public.complete_profile('Clue Two','avatar_02'); perform public.join_room((select code from cv)); perform public.set_ready(true); end $$;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000003',true);
do $$ begin perform public.complete_profile('Clue Three','avatar_03'); perform public.join_room((select code from cv)); perform public.set_ready(true); end $$;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000004',true);
do $$ begin perform public.complete_profile('Clue Out','avatar_04'); end $$;
select throws_ok($$select public.acknowledge_role()$$,'P0001','not_game_participant','Outsider cannot acknowledge');

select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000001',true);
do $$ begin perform public.start_game('61000000-0000-4000-8000-000000000012'); end $$;
set local role postgres;
update public.games set keyword_id=(select id from public.words where word_vi='Dưa hấu' limit 1);
create temporary table ordered as select player_id,turn_order from public.game_players;
grant select on ordered to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select player_id::text from ordered where turn_order=1),true);
select lives_ok($$select public.acknowledge_role()$$,'Participant acknowledges role');
select is((public.acknowledge_role()->>'revision')::integer,2,'Acknowledgement retry is revision-idempotent');
select set_config('request.jwt.claim.sub',(select player_id::text from ordered where turn_order=2),true);
do $$ begin perform public.acknowledge_role(); end $$;
select set_config('request.jwt.claim.sub',(select player_id::text from ordered where turn_order=3),true);
select is(public.acknowledge_role()->>'status','clue','Final acknowledgement enters clue');
set local role postgres;
select is((select count(*)::integer from public.game_turns),1,'Exactly one first turn exists');
select is((select turn_index from public.game_turns),1,'First turn index is one');
select is((select player_id from public.game_turns),(select player_id from ordered where turn_order=1),'First turn follows immutable order');
select is((select clue_seconds from public.games),(select clue_seconds from public.rooms),'Clue seconds snapshotted');
select is((select discussion_seconds from public.games),(select discussion_seconds from public.rooms),'Discussion seconds snapshotted');

set local role authenticated;
select set_config('request.jwt.claim.sub',(select player_id::text from ordered where turn_order=2),true);
select throws_ok($$select public.submit_clue('Mùa hè')$$,'P0001','not_current_turn','Other participant cannot submit');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000004',true);
select throws_ok($$select public.submit_clue('Mùa hè')$$,'P0001','not_game_participant','Outsider cannot submit');
select set_config('request.jwt.claim.sub',(select player_id::text from ordered where turn_order=1),true);
select throws_ok($$select public.submit_clue('   ')$$,'P0001','invalid_clue','Blank clue rejected');
select throws_ok($$select public.submit_clue(repeat('a',81))$$,'P0001','invalid_clue','Overlong clue rejected');
select throws_ok($$select public.submit_clue(E'good\nclue')$$,'P0001','invalid_clue','Control character rejected');
select is(public.submit_clue('DƯA-HẤU')->>'action_error','invalid_clue','Uppercase punctuation keyword rejected generically');
select is(public.submit_clue('dua   hau')->>'action_error','invalid_clue','No-diacritic keyword rejected generically');
select is(public.submit_clue('Watermelon')->>'action_error','invalid_clue','English keyword rejected generically');
select lives_ok($$select public.submit_clue('cam kết mùa hè')$$,'Unrelated token is accepted without substring false positive');
set local role postgres;
select is((select status from public.game_turns where turn_index=1),'submitted','Successful clue completes turn');
select is((select count(*)::integer from public.game_turns where status='active'),1,'Exactly one next active turn');
select is((select turn_index from public.game_turns where status='active'),2,'Submission advances sequentially');
select is((select clue_text from public.clues),'cam kết mùa hè','Vietnamese clue preserved');

set local role authenticated;
select set_config('request.jwt.claim.sub',(select player_id::text from ordered where turn_order=2),true);
select throws_ok($$insert into public.clues(game_id,turn_id,player_id,turn_index,clue_text) values(gen_random_uuid(),1,auth.uid(),9,'hack')$$,'42501','permission denied for table clues','Direct clue insert denied');
set local role postgres;
update public.game_turns set started_at=clock_timestamp()-interval '2 seconds', ends_at=clock_timestamp()-interval '1 second' where status='active';
set local role authenticated;
select lives_ok($$select public.advance_game_if_due()$$,'Due turn advances');
set local role postgres;
select is((select status from public.game_turns where turn_index=2),'timed_out','Timeout explicitly recorded');
select is((select count(*)::integer from public.clues where turn_index=2),0,'Timeout inserts no fake clue');
select is((select turn_index from public.game_turns where status='active'),3,'Timeout advances to next player');
set local role authenticated;
select set_config('request.jwt.claim.sub',(select player_id::text from ordered where turn_order=3),true);
select is(public.submit_clue('Giải khát')->>'status','discussion','Final clue enters discussion');
select ok(not (public.get_current_game() ?| array['keyword_id','keyword','role']),'Public clue snapshot excludes secrets');
select is((public.get_current_game()->'turns'->0->>'clue_text'),'cam kết mùa hè','Public snapshot exposes submitted clue');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000004',true);
select throws_ok($$select * from public.clues$$,'42501','permission denied for table clues','Outsider cannot select clues directly');
select is(public.get_current_game(),null,'Outsider receives no game snapshot');

select * from finish();
rollback;
