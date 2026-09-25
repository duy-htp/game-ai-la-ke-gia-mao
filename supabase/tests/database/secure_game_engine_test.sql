begin;
select plan(32);

insert into auth.users(id,email) select id, suffix||'@game.test' from (values
 ('30000000-0000-4000-8000-00000000000a'::uuid,'host'),
 ('30000000-0000-4000-8000-00000000000b'::uuid,'b'),
 ('30000000-0000-4000-8000-00000000000c'::uuid,'c'),
 ('30000000-0000-4000-8000-00000000000d'::uuid,'outsider')
) u(id,suffix);

set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-00000000000a',true);
do $$ begin perform public.complete_profile('Game Host','avatar_01'); end $$;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-00000000000b',true);
do $$ begin perform public.complete_profile('Game B','avatar_02'); end $$;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-00000000000c',true);
do $$ begin perform public.complete_profile('Game C','avatar_03'); end $$;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-00000000000d',true);
do $$ begin perform public.complete_profile('Outsider','avatar_04'); end $$;

select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-00000000000a',true);
do $$ begin perform public.create_room('impostor',6,'93000000-0000-4000-8000-000000000001'); end $$;
set local role postgres;
create temporary table game_values as select id room_id,code from public.rooms where created_by='30000000-0000-4000-8000-00000000000a';
grant select on game_values to authenticated;
select is((select count(*)::integer from public.words),100,'Seeds 100 development words');
select is((select min(n)::integer from (select count(*) n from public.words group by category_id) x),10,'Every category has at least ten words');

set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-00000000000b',true);
do $$ begin perform public.join_room((select code from game_values)); perform public.set_ready(true); end $$;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-00000000000c',true);
do $$ begin perform public.join_room((select code from game_values)); perform public.set_ready(true); end $$;
select throws_ok($$ select public.start_game('93000000-0000-4000-8000-000000000009') $$,'P0001','not_host','Non-host cannot start');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-00000000000d',true);
select throws_ok($$ select public.start_game('93000000-0000-4000-8000-000000000008') $$,'P0001','not_room_member','Outsider cannot start');

select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-00000000000a',true);
select lives_ok($$ select public.start_game('93000000-0000-4000-8000-000000000002') $$,'Eligible host starts game');
select is((public.start_game('93000000-0000-4000-8000-000000000002')->>'game_id')::uuid,(public.get_current_game()->>'game_id')::uuid,'Start retry returns same game');
select ok(not (public.get_current_game() ?| array['keyword_id','keyword','role','category_id']),'Public snapshot excludes role and keyword');
select ok((public.get_current_game()->'participants'->0) ?& array['player_id','username','avatar_id'],'Public participants contain safe fields');

set local role postgres;
select is((select count(*)::integer from public.games),1,'Only one game created');
select is((select status from public.rooms where id=(select room_id from game_values)),'in_game','Room atomically enters in_game');
select is((select status from public.games),'role_reveal','Game begins in role_reveal');
select is((select round_number from public.games),1,'First round number is one');
select is((select count(*)::integer from public.game_players),3,'Active members are snapshotted');
select is((select count(*)::integer from public.game_players where role='impostor'),1,'Three players produce exactly one impostor');
select is((select count(distinct turn_order)::integer from public.game_players),3,'Turn orders are unique');
select is((select min(turn_order) from public.game_players),1,'Turn order starts at one');
select is((select max(turn_order) from public.game_players),3,'Turn order covers participant count');
select ok((select category_id=(select category_id from public.words where id=keyword_id) from public.games),'Selected keyword belongs to selected category');
select ok((select phase_started_at <= phase_ends_at from public.games),'Role reveal uses server timestamps');

create temporary table secret_players as
select max(player_id::text) filter(where role='normal')::uuid normal_id,
       max(player_id::text) filter(where role='impostor')::uuid impostor_id from public.game_players;
grant select on secret_players to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select normal_id::text from secret_players),true);
select is((public.get_my_game_secret()->>'role'),'normal','Normal receives own role');
select ok((public.get_my_game_secret()->>'word_vi') is not null and (public.get_my_game_secret()->>'word_en') is not null,'Normal receives both names for same selected concept');
select set_config('request.jwt.claim.sub',(select impostor_id::text from secret_players),true);
select is((public.get_my_game_secret()->>'role'),'impostor','Impostor receives own role');
select ok((public.get_my_game_secret()->>'word_vi') is null and (public.get_my_game_secret()->>'word_en') is null,'Impostor receives no keyword');
select throws_ok($$ select * from public.words $$,'42501','permission denied for table words','Authenticated cannot enumerate words');
select throws_ok($$ select * from public.games $$,'42501','permission denied for table games','Authenticated cannot read keyword_id');
select throws_ok($$ select * from public.game_players $$,'42501','permission denied for table game_players','Authenticated cannot read roles');
select throws_ok($$ update public.game_players set role='normal' $$,'42501','permission denied for table game_players','Client cannot change roles');
select throws_ok($$ select public.leave_room() $$,'P0001','room_in_game','Lobby leave is frozen during game');
select throws_ok($$ select public.set_ready(false) $$,'P0001','room_closed','Ready is frozen during game');

select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-00000000000d',true);
select is(public.get_current_game(),null,'Outsider cannot retrieve game snapshot');
select throws_ok($$ select public.get_my_game_secret() $$,'P0001','not_game_participant','Outsider cannot retrieve a secret');
set local role postgres;
select is((select count(*)::integer from information_schema.parameters where specific_schema='public' and specific_name like 'get_my_game_secret%' and parameter_mode='IN'),0,'Secret RPC accepts no victim identifier');

select * from finish();
rollback;
