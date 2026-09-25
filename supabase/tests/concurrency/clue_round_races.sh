#!/usr/bin/env bash
set -euo pipefail
db="supabase_db_game-ai-la-ke-gia-mao"
game="62000000-0000-4000-8000-000000000010"
room="62000000-0000-4000-8000-000000000011"
p1="62000000-0000-4000-8000-000000000001"
p2="62000000-0000-4000-8000-000000000002"
p3="62000000-0000-4000-8000-000000000003"
run_as() {
  local player="$1" sql="$2"
  docker exec "$db" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -Atq -c "begin; set local role authenticated; select set_config('request.jwt.claim.sub','$player',true); $sql; commit;"
}
cleanup() {
  docker exec "$db" psql -U postgres -d postgres -q -c "delete from public.clues where game_id='$game'; delete from public.game_turns where game_id='$game'; delete from public.game_players where game_id='$game'; delete from public.games where id='$game'; delete from public.room_players where room_id='$room'; delete from public.rooms where id='$room'; delete from public.profiles where id in ('$p1','$p2','$p3'); delete from auth.users where id in ('$p1','$p2','$p3');" >/dev/null 2>&1 || true
}
trap cleanup EXIT
docker exec "$db" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "
insert into auth.users(id,email) values('$p1','race1@clue.test'),('$p2','race2@clue.test'),('$p3','race3@clue.test');
insert into public.profiles(id,username,avatar_id) values('$p1','Race One','avatar_01'),('$p2','Race Two','avatar_02'),('$p3','Race Three','avatar_03');
insert into public.rooms(id,code,game_type,max_players,host_id,created_by,status,create_request_id,impostor_count,clue_seconds,discussion_seconds) values('$room','RACE62','impostor',3,'$p1','$p1','in_game','62000000-0000-4000-8000-000000000013',1,15,60);
insert into public.room_players(room_id,player_id,seat,is_ready) values('$room','$p1',1,true),('$room','$p2',2,true),('$room','$p3',3,true);
insert into public.games(id,room_id,round_number,status,category_id,keyword_id,phase_started_at,phase_ends_at,started_by,start_request_id,impostor_count,clue_seconds,discussion_seconds)
select '$game','$room',1,'role_reveal',w.category_id,w.id,clock_timestamp()-interval '20 seconds',clock_timestamp()-interval '1 second','$p1','62000000-0000-4000-8000-000000000012',1,15,60 from public.words w where w.word_vi='Dưa hấu' limit 1;
insert into public.game_players(game_id,player_id,role,turn_order,role_acknowledged_at) values('$game','$p1','normal',1,clock_timestamp()),('$game','$p2','normal',2,clock_timestamp()),('$game','$p3','impostor',3,null);"

set +e
run_as "$p3" "select public.acknowledge_role();" >/tmp/clue_ack_1 2>&1 & a=$!
run_as "$p1" "select public.advance_game_if_due();" >/tmp/clue_ack_2 2>&1 & b=$!
wait "$a"; wait "$b"
set -e
read -r status active turns <<<"$(docker exec "$db" psql -U postgres -d postgres -Atq -F ' ' -c "select g.status,count(*) filter(where gt.status='active'),count(gt.id) from public.games g left join public.game_turns gt on gt.game_id=g.id where g.id='$game' group by g.status")"
[[ "$status $active $turns" == "clue 1 1" ]] || { echo "ack/deadline race failed: $status $active $turns"; exit 1; }

docker exec "$db" psql -U postgres -d postgres -q -c "update public.game_turns set started_at=clock_timestamp()-interval '2 seconds',ends_at=clock_timestamp()-interval '1 second' where game_id='$game' and status='active';" >/dev/null
run_as "$p1" "select public.advance_game_if_due();" >/tmp/clue_advance_1 2>&1 & a=$!
run_as "$p2" "select public.advance_game_if_due();" >/tmp/clue_advance_2 2>&1 & b=$!
wait "$a"; wait "$b"
read -r timed active idx <<<"$(docker exec "$db" psql -U postgres -d postgres -Atq -F ' ' -c "select count(*) filter(where status='timed_out'),count(*) filter(where status='active'),max(turn_index) from public.game_turns where game_id='$game'")"
[[ "$timed $active $idx" == "1 1 2" ]] || { echo "double advance: $timed $active $idx"; exit 1; }

docker exec "$db" psql -U postgres -d postgres -q -c "update public.game_turns set started_at=clock_timestamp()-interval '2 seconds',ends_at=clock_timestamp()-interval '1 second' where game_id='$game' and status='active';" >/dev/null
set +e
run_as "$p2" "select public.submit_clue('Đúng giờ');" >/tmp/clue_submit_race 2>&1 & a=$!
run_as "$p1" "select public.advance_game_if_due();" >/tmp/clue_timeout_race 2>&1 & b=$!
wait "$a"; wait "$b"
set -e
read -r completed active idx <<<"$(docker exec "$db" psql -U postgres -d postgres -Atq -F ' ' -c "select count(*) filter(where turn_index=2 and status in ('submitted','timed_out')),count(*) filter(where status='active'),max(turn_index) from public.game_turns where game_id='$game'")"
[[ "$completed $active $idx" == "1 1 3" ]] || { echo "submit/timeout race failed: $completed $active $idx"; exit 1; }

run_as "$p3" "select public.submit_clue('Bí ẩn');" >/tmp/clue_final_1 2>&1 & a=$!
run_as "$p3" "select public.submit_clue('Bí ẩn');" >/tmp/clue_final_2 2>&1 & b=$!
set +e; wait "$a"; wait "$b"; set -e
read -r phase clues active <<<"$(docker exec "$db" psql -U postgres -d postgres -Atq -F ' ' -c "select g.status,count(distinct c.id),count(*) filter(where gt.status='active') from public.games g join public.game_turns gt on gt.game_id=g.id left join public.clues c on c.game_id=g.id where g.id='$game' group by g.status")"
[[ "$phase $clues $active" == "discussion 1 0" ]] || { echo "final duplicate failed: $phase $clues $active"; exit 1; }
echo "PASS: acknowledgement/deadline, duplicate advance, submit/timeout, and final duplicate races serialized"
