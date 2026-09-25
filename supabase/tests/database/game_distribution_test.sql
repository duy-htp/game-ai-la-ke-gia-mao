begin;
select plan(8);

create temporary table scenarios(name text primary key, room_id uuid, host_id uuid, player_count int, impostors int);
insert into scenarios values
 ('six','51000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000001',6,1),
 ('seven_one','51000000-0000-4000-8000-000000000002','52000000-0000-4000-8000-000000000101',7,1),
 ('seven_two','51000000-0000-4000-8000-000000000003','52000000-0000-4000-8000-000000000201',7,2),
 ('ten_two','51000000-0000-4000-8000-000000000004','52000000-0000-4000-8000-000000000301',10,2);

insert into auth.users(id,email)
select ('52000000-0000-4000-8000-'||lpad((base+n)::text,12,'0'))::uuid,
  name||'-'||n||'@distribution.test'
from (values('six',0,6),('seven_one',100,7),('seven_two',200,7),('ten_two',300,10)) x(name,base,total)
cross join lateral generate_series(1,total) n;
insert into public.profiles(id,username,avatar_id)
select id,'Distribution Player','avatar_01' from auth.users where email like '%@distribution.test';

insert into public.rooms(id,code,host_id,created_by,game_type,status,max_players,create_request_id,impostor_count)
select room_id,case name when 'six' then 'D5ST6A' when 'seven_one' then 'D5ST7A' when 'seven_two' then 'D5ST7B' else 'D5ST9A' end,
  host_id,host_id,'impostor','waiting',player_count,gen_random_uuid(),impostors from scenarios;

insert into public.room_players(room_id,player_id,seat,is_ready)
select s.room_id,('52000000-0000-4000-8000-'||lpad((x.base+n)::text,12,'0'))::uuid,n,n>1
from scenarios s join (values('six',0),('seven_one',100),('seven_two',200),('ten_two',300)) x(name,base) using(name)
cross join lateral generate_series(1,s.player_count) n;

do $$ declare s record; begin
  for s in select * from scenarios loop
    perform set_config('request.jwt.claim.sub',s.host_id::text,true);
    execute 'set local role authenticated';
    perform public.start_game(gen_random_uuid());
    execute 'reset role';
  end loop;
end $$;

select is((select count(*)::int from public.game_players gp join public.games g on g.id=gp.game_id join scenarios s on s.room_id=g.room_id where s.name='six' and gp.role='impostor'),1,'6 players have exactly 1 impostor');
select is((select count(*)::int from public.game_players gp join public.games g on g.id=gp.game_id join scenarios s on s.room_id=g.room_id where s.name='seven_one' and gp.role='impostor'),1,'7 players setting 1 has exactly 1 impostor');
select is((select count(*)::int from public.game_players gp join public.games g on g.id=gp.game_id join scenarios s on s.room_id=g.room_id where s.name='seven_two' and gp.role='impostor'),2,'7 players setting 2 has exactly 2 impostors');
select is((select count(*)::int from public.game_players gp join public.games g on g.id=gp.game_id join scenarios s on s.room_id=g.room_id where s.name='ten_two' and gp.role='impostor'),2,'10 players setting 2 has exactly 2 impostors');
select ok((select count(*)=6 and min(turn_order)=1 and max(turn_order)=6 and count(distinct turn_order)=6 from public.game_players gp join public.games g on g.id=gp.game_id join scenarios s on s.room_id=g.room_id where s.name='six'),'6-player turn order covers 1..6');
select ok((select count(*)=7 and min(turn_order)=1 and max(turn_order)=7 and count(distinct turn_order)=7 from public.game_players gp join public.games g on g.id=gp.game_id join scenarios s on s.room_id=g.room_id where s.name='seven_one'),'7-player turn order covers 1..7');
select ok((select count(*)=7 and min(turn_order)=1 and max(turn_order)=7 and count(distinct turn_order)=7 from public.game_players gp join public.games g on g.id=gp.game_id join scenarios s on s.room_id=g.room_id where s.name='seven_two'),'second 7-player turn order covers 1..7');
select ok((select count(*)=10 and min(turn_order)=1 and max(turn_order)=10 and count(distinct turn_order)=10 from public.game_players gp join public.games g on g.id=gp.game_id join scenarios s on s.room_id=g.room_id where s.name='ten_two'),'10-player turn order covers 1..10');
select * from finish();
rollback;
