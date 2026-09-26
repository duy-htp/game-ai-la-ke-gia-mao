#!/usr/bin/env bash
set -euo pipefail
db="supabase_db_game-ai-la-ke-gia-mao"; game="72000000-0000-4000-8000-000000000020"; room="72000000-0000-4000-8000-000000000010"
p1="72000000-0000-4000-8000-000000000001"; p2="72000000-0000-4000-8000-000000000002"; p3="72000000-0000-4000-8000-000000000003"
run_as(){ docker exec "$db" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -Atq -c "begin;set local role authenticated;select set_config('request.jwt.claim.sub','$1',true);$2;commit;"; }
cleanup(){ docker exec "$db" psql -U postgres -d postgres -q -c "delete from votes where voting_round_id in(select id from voting_rounds where game_id='$game');delete from voting_round_candidates where voting_round_id in(select id from voting_rounds where game_id='$game');delete from voting_rounds where game_id='$game';delete from game_players where game_id='$game';delete from games where id='$game';delete from room_players where room_id='$room';delete from rooms where id='$room';delete from profiles where id in('$p1','$p2','$p3');delete from auth.users where id in('$p1','$p2','$p3');" >/dev/null 2>&1||true; rm -f /tmp/vote_race_*; }
trap cleanup EXIT
docker exec "$db" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "
insert into auth.users(id,email)values('$p1','vr1@test'),('$p2','vr2@test'),('$p3','vr3@test');insert into profiles(id,username,avatar_id)values('$p1','VR One','avatar_01'),('$p2','VR Two','avatar_02'),('$p3','VR Three','avatar_03');
insert into rooms(id,code,created_by,host_id,game_type,status,max_players,create_request_id)values('$room','ABC235','$p1','$p1','impostor','in_game',3,'72000000-0000-4000-8000-000000000011');
insert into room_players(room_id,player_id,seat,is_ready)values('$room','$p1',1,true),('$room','$p2',2,true),('$room','$p3',3,true);
insert into games(id,room_id,round_number,status,category_id,keyword_id,phase_started_at,phase_ends_at,started_by,start_request_id,impostor_count,clue_seconds,discussion_seconds)select '$game','$room',1,'discussion',category_id,id,clock_timestamp()-interval '61 seconds',clock_timestamp()-interval '1 second','$p1','72000000-0000-4000-8000-000000000021',1,15,60 from words limit 1;
insert into game_players(game_id,player_id,role,turn_order,discussion_ready_at)values('$game','$p1','normal',1,clock_timestamp()),('$game','$p2','normal',2,clock_timestamp()),('$game','$p3','impostor',3,null);"
set +e; run_as "$p3" "select set_discussion_ready(true);" >/tmp/vote_race_ready 2>&1&a=$!;run_as "$p1" "select advance_game_if_due();" >/tmp/vote_race_due 2>&1&b=$!;wait "$a";wait "$b";set -e
[[ "$(docker exec "$db" psql -U postgres -d postgres -Atq -c "select count(*) from voting_rounds where game_id='$game'")" == 1 ]]||{ echo 'duplicate voting initialization';exit 1;}
run_as "$p1" "select submit_vote('$p2');" >/tmp/vote_race_dup1 2>&1&a=$!;run_as "$p1" "select submit_vote('$p2');" >/tmp/vote_race_dup2 2>&1&b=$!;wait "$a";wait "$b"
run_as "$p2" "select submit_vote('$p1');" >/tmp/vote_race_final1 2>&1&a=$!;run_as "$p3" "select submit_vote('$p2');" >/tmp/vote_race_final2 2>&1&b=$!;wait "$a";wait "$b"
read -r votes completed phase <<<"$(docker exec "$db" psql -U postgres -d postgres -Atq -F ' ' -c "select count(v.id),count(distinct vr.id)filter(where vr.status='completed'),min(g.status) from games g join voting_rounds vr on vr.game_id=g.id left join votes v on v.voting_round_id=vr.id where g.id='$game' group by g.id")"
[[ "$votes $completed $phase" == "3 1 vote_result" ]]||{ echo "final vote race failed $votes $completed $phase";exit 1;}

docker exec "$db" psql -U postgres -d postgres -q -c "delete from votes where voting_round_id in(select id from voting_rounds where game_id='$game');delete from voting_round_candidates where voting_round_id in(select id from voting_rounds where game_id='$game');delete from voting_rounds where game_id='$game';update games set status='discussion',phase_started_at=clock_timestamp(),phase_ends_at=clock_timestamp()+interval '60 seconds',eliminated_player_id=null where id='$game';update game_players set discussion_ready_at=clock_timestamp() where game_id='$game';" >/dev/null
run_as "$p1" "select set_discussion_ready(true);" >/dev/null
round="$(docker exec "$db" psql -U postgres -d postgres -Atq -c "select id from voting_rounds where game_id='$game'")"
run_as "$p1" "select submit_vote('$p2');" >/dev/null;run_as "$p2" "select submit_vote('$p1');" >/dev/null
docker exec "$db" psql -U postgres -d postgres -q -c "update voting_rounds set started_at=clock_timestamp()-interval '31 seconds',ends_at=clock_timestamp()-interval '1 second' where id=$round;update games set phase_started_at=clock_timestamp()-interval '31 seconds',phase_ends_at=clock_timestamp()-interval '1 second' where id='$game';" >/dev/null
run_as "$p3" "select advance_game_if_due();" >/dev/null
docker exec "$db" psql -U postgres -d postgres -q -c "update games set phase_started_at=clock_timestamp()-interval '6 seconds',phase_ends_at=clock_timestamp()-interval '1 second' where id='$game';" >/dev/null
run_as "$p1" "select advance_game_if_due();" >/tmp/vote_race_revote1 2>&1&a=$!;run_as "$p2" "select advance_game_if_due();" >/tmp/vote_race_revote2 2>&1&b=$!;wait "$a";wait "$b"
[[ "$(docker exec "$db" psql -U postgres -d postgres -Atq -c "select count(*) from voting_rounds where game_id='$game'")" == 2 ]]||{ echo 'duplicate revote';exit 1;}
echo "PASS: ready/deadline, duplicate retry, final votes and tied-result advancement serialize"
