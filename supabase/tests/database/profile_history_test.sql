begin;select plan(22);
insert into auth.users(id,email)values('83000000-0000-4000-8000-000000000001','profile1@test'),('83000000-0000-4000-8000-000000000002','profile2@test');
insert into profiles(id,username,avatar_id,games_played,games_won,normal_wins,correct_votes)values
('83000000-0000-4000-8000-000000000001','History One','avatar_01',3,2,2,2),('83000000-0000-4000-8000-000000000002','History Two','avatar_02',1,0,0,0);
insert into rooms(id,code,created_by,host_id,game_type,status,max_players,create_request_id)values
('83000000-0000-4000-8000-000000000010','ABC238','83000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000001','impostor','in_game',6,'83000000-0000-4000-8000-000000000011');
insert into room_players(room_id,player_id,seat,is_ready)values('83000000-0000-4000-8000-000000000010','83000000-0000-4000-8000-000000000001',1,true),('83000000-0000-4000-8000-000000000010','83000000-0000-4000-8000-000000000002',2,true);
create temporary table seedword as select id,category_id from words limit 1;
insert into games(id,room_id,round_number,status,category_id,keyword_id,phase_started_at,started_by,start_request_id,impostor_count,clue_seconds,discussion_seconds,winner_team,result_reason,finished_at)
select x.id,'83000000-0000-4000-8000-000000000010',x.r,x.s,w.category_id,w.id,now(),'83000000-0000-4000-8000-000000000001',x.req,1,15,60,case when x.s='result'then'normal'end,case when x.s='result'then'impostor_final_guess_wrong'end,x.finished
from seedword w cross join(values('83000000-0000-4000-8000-000000000020'::uuid,1,'result', '83000000-0000-4000-8000-000000000021'::uuid,now()-interval'3 days'),('83000000-0000-4000-8000-000000000030',2,'result','83000000-0000-4000-8000-000000000031',now()-interval'2 days'),('83000000-0000-4000-8000-000000000040',3,'result','83000000-0000-4000-8000-000000000041',now()-interval'1 day'),('83000000-0000-4000-8000-000000000050',4,'discussion','83000000-0000-4000-8000-000000000051',null))x(id,r,s,req,finished);
insert into game_players(game_id,player_id,role,turn_order)select id,'83000000-0000-4000-8000-000000000001','normal',1 from games where id in('83000000-0000-4000-8000-000000000020','83000000-0000-4000-8000-000000000030','83000000-0000-4000-8000-000000000040','83000000-0000-4000-8000-000000000050');
insert into game_players(game_id,player_id,role,turn_order)values('83000000-0000-4000-8000-000000000020','83000000-0000-4000-8000-000000000002','impostor',2);
insert into game_rewards(game_id,player_id,xp_delta,coins_delta,resulting_xp,resulting_coins,resulting_level)values
('83000000-0000-4000-8000-000000000020','83000000-0000-4000-8000-000000000001',180,20,180,20,1),('83000000-0000-4000-8000-000000000030','83000000-0000-4000-8000-000000000001',150,20,330,40,1),('83000000-0000-4000-8000-000000000040','83000000-0000-4000-8000-000000000001',30,10,360,50,1),('83000000-0000-4000-8000-000000000020','83000000-0000-4000-8000-000000000002',0,10,0,10,1);

set local role authenticated;select set_config('request.jwt.claim.sub','83000000-0000-4000-8000-000000000001',true);
select is(public.get_my_profile()->>'username','History One','Caller gets own profile');
select is((public.get_my_profile()->>'games_played')::int,3,'Profile exposes server stats');
select is(public.update_my_profile('  Tên   Mới  ','avatar_12')->>'username','Tên Mới','Username trims and collapses whitespace');
select is(public.get_my_profile()->>'avatar_id','avatar_12','Avatar updates');
select throws_ok($$select public.update_my_profile('x','avatar_01')$$,'P0001','invalid_username','Invalid username rejected');
select throws_ok($$select public.update_my_profile('Valid','remote-url')$$,'P0001','invalid_avatar','Invalid avatar rejected');
select is(jsonb_array_length(public.get_my_game_history()->'items'),3,'History includes own completed games only');
select is(public.get_my_game_history()->'items'->0->>'game_id','83000000-0000-4000-8000-000000000040','History newest first');
select is((public.get_my_game_history()->'items'->0->>'xp_gained')::int,30,'History reward matches ledger');
select is(public.get_my_game_history()->'items'->0->>'winner_team','normal','History winner persisted');
select is(jsonb_array_length(public.get_my_game_history(2)->'items'),2,'Page limit enforced');
create temporary table cursor as select (public.get_my_game_history(2)->>'next_finished_at')::timestamptz t,(public.get_my_game_history(2)->>'next_game_id')::uuid id;grant select on cursor to authenticated;
select is(jsonb_array_length(public.get_my_game_history(2,(select t from cursor),(select id from cursor))->'items'),1,'Keyset cursor returns next page');
select throws_ok($$select public.get_my_game_history(20,now(),null)$$,'P0001','invalid_history_cursor','Partial cursor rejected');
select throws_ok($$select public.get_my_game_history(100,null,null)$$,'P0001','invalid_history_limit','Oversized page rejected');
select set_config('request.jwt.claim.sub','83000000-0000-4000-8000-000000000002',true);
select is(jsonb_array_length(public.get_my_game_history()->'items'),1,'Other caller sees only own history');
select is(public.get_my_profile()->>'username','History Two','Cannot request another profile');
select set_config('request.jwt.claim.sub','83000000-0000-4000-8000-000000000001',true);
select throws_ok($$update public.profiles set xp=999999 where id='83000000-0000-4000-8000-000000000001'$$,'42501',null,'Direct economy update denied');
select throws_ok($$update public.profiles set games_won=999 where id='83000000-0000-4000-8000-000000000001'$$,'42501',null,'Direct stats update denied');
select throws_ok($$select * from public.game_rewards$$,'42501',null,'Reward table remains private');
set local role postgres;
select throws_ok($$update public.profiles set games_won=4 where id='83000000-0000-4000-8000-000000000001'$$,'23514',null,'Wins cannot exceed games played');
select throws_ok($$update public.profiles set correct_votes=4 where id='83000000-0000-4000-8000-000000000001'$$,'23514',null,'Correct votes cannot exceed games played');
select ok((select games_won=normal_wins+impostor_wins from profiles where id='83000000-0000-4000-8000-000000000001'),'Win-role stats remain consistent');
select * from finish();rollback;
