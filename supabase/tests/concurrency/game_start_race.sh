#!/usr/bin/env bash
set -euo pipefail
db="supabase_db_game-ai-la-ke-gia-mao"
host="40000000-0000-4000-8000-000000000001"
b="40000000-0000-4000-8000-000000000002"
c="40000000-0000-4000-8000-000000000003"
create_req="49000000-0000-4000-8000-000000000001"
start_req="49000000-0000-4000-8000-000000000002"
out1="$(mktemp)"; out2="$(mktemp)"
cleanup() {
  docker exec "$db" psql -U postgres -d postgres -q -c "
    delete from public.game_players where player_id in ('$host','$b','$c');
    delete from public.games where started_by='$host';
    delete from public.room_players where player_id in ('$host','$b','$c');
    delete from public.rooms where created_by='$host';
    delete from public.profiles where id in ('$host','$b','$c');
    delete from auth.users where id in ('$host','$b','$c');" >/dev/null 2>&1 || true
  rm -f "$out1" "$out2"
}
trap cleanup EXIT
docker exec "$db" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "
 insert into auth.users(id,email) values ('$host','start-host@test'),('$b','start-b@test'),('$c','start-c@test');
 insert into public.profiles(id,username,avatar_id) values ('$host','Start Host','avatar_01'),('$b','Start B','avatar_02'),('$c','Start C','avatar_03');
 begin; set local role authenticated; select set_config('request.jwt.claim.sub','$host',true); select public.create_room('impostor',6,'$create_req'); commit;" >/dev/null
code="$(docker exec "$db" psql -U postgres -d postgres -Atq -c "select code from public.rooms where created_by='$host'")"
for player in "$b" "$c"; do
  docker exec "$db" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "begin; set local role authenticated; select set_config('request.jwt.claim.sub','$player',true); select public.join_room('$code'); select public.set_ready(true); commit;" >/dev/null
done
set +e
for output in "$out1" "$out2"; do
  docker exec "$db" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -Atq -c "begin; set local role authenticated; select set_config('request.jwt.claim.sub','$host',true); select public.start_game('$start_req')->>'game_id'; commit;" >"$output" 2>&1 &
done
wait; result=$?
set -e
if [[ "$result" -ne 0 ]]; then cat "$out1" "$out2" >&2; exit 1; fi
id1="$(grep -E '^[0-9a-f-]{36}$' "$out1" | tail -1)"; id2="$(grep -E '^[0-9a-f-]{36}$' "$out2" | tail -1)"
read -r games players rounds status <<<"$(docker exec "$db" psql -U postgres -d postgres -Atq -F ' ' -c "select count(distinct g.id),count(gp.id),count(distinct g.round_number),min(r.status) from public.games g join public.game_players gp on gp.game_id=g.id join public.rooms r on r.id=g.room_id where g.started_by='$host' group by r.id")"
if [[ -z "$id1" || "$id1" != "$id2" || "$games" != 1 || "$players" != 3 || "$rounds" != 1 || "$status" != in_game ]]; then
  echo "Start race invariant failed ids=$id1/$id2 games=$games players=$players rounds=$rounds status=$status" >&2; exit 1
fi
echo "PASS: concurrent start returned one game $id1 with 3 snapshotted players"
