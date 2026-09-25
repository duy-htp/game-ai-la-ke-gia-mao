#!/usr/bin/env bash
set -euo pipefail

database_container="supabase_db_game-ai-la-ke-gia-mao"
host_id="20000000-0000-4000-8000-000000000001"
member_id="20000000-0000-4000-8000-000000000002"
joiner_one_id="20000000-0000-4000-8000-000000000003"
joiner_two_id="20000000-0000-4000-8000-000000000004"
request_id="29000000-0000-4000-8000-000000000001"
output_one="$(mktemp)"
output_two="$(mktemp)"

cleanup() {
  docker exec "$database_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "
    delete from public.room_players where player_id in ('$host_id', '$member_id', '$joiner_one_id', '$joiner_two_id');
    delete from public.rooms where created_by = '$host_id';
    delete from public.profiles where id in ('$host_id', '$member_id', '$joiner_one_id', '$joiner_two_id');
    delete from auth.users where id in ('$host_id', '$member_id', '$joiner_one_id', '$joiner_two_id');
  " >/dev/null 2>&1 || true
  rm -f "$output_one" "$output_two"
}
trap cleanup EXIT

docker exec "$database_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "
  insert into auth.users (id, email) values
    ('$host_id', 'race-host@example.test'),
    ('$member_id', 'race-member@example.test'),
    ('$joiner_one_id', 'race-one@example.test'),
    ('$joiner_two_id', 'race-two@example.test');
  insert into public.profiles (id, username, avatar_id) values
    ('$host_id', 'Race Host', 'avatar_01'),
    ('$member_id', 'Race Member', 'avatar_02'),
    ('$joiner_one_id', 'Race One', 'avatar_03'),
    ('$joiner_two_id', 'Race Two', 'avatar_04');
" >/dev/null

docker exec "$database_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "
  begin;
  set local role authenticated;
  select set_config('request.jwt.claim.sub', '$host_id', true);
  select public.create_room('impostor', 3, '$request_id');
  commit;
" >/dev/null

room_code="$(docker exec "$database_container" psql -U postgres -d postgres -Atq -c "select code from public.rooms where created_by = '$host_id';")"

docker exec "$database_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "
  begin;
  set local role authenticated;
  select set_config('request.jwt.claim.sub', '$member_id', true);
  select public.join_room('$room_code');
  commit;
" >/dev/null

docker exec "$database_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "
  begin;
  select id from public.rooms where code = '$room_code' for update;
  select pg_sleep(2);
  commit;
" >/dev/null &
blocker_pid=$!
sleep 0.2

set +e
docker exec "$database_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "
  begin;
  set local role authenticated;
  select set_config('request.jwt.claim.sub', '$joiner_one_id', true);
  select public.join_room('$room_code');
  commit;
" >"$output_one" 2>&1 &
joiner_one_pid=$!

docker exec "$database_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "
  begin;
  set local role authenticated;
  select set_config('request.jwt.claim.sub', '$joiner_two_id', true);
  select public.join_room('$room_code');
  commit;
" >"$output_two" 2>&1 &
joiner_two_pid=$!

wait "$blocker_pid"
wait "$joiner_one_pid"
result_one=$?
wait "$joiner_two_pid"
result_two=$?
set -e

if [[ "$result_one" -eq "$result_two" ]]; then
  echo "Expected exactly one concurrent join to succeed" >&2
  sed -n '1,20p' "$output_one" >&2
  sed -n '1,20p' "$output_two" >&2
  exit 1
fi

failed_output="$output_one"
if [[ "$result_one" -eq 0 ]]; then
  failed_output="$output_two"
fi
if ! grep -q 'room_full' "$failed_output"; then
  echo "Expected losing join to fail with room_full" >&2
  sed -n '1,20p' "$failed_output" >&2
  exit 1
fi

read -r active_count distinct_seats <<<"$(
  docker exec "$database_container" psql -U postgres -d postgres -Atq -F ' ' -c "
    select count(*), count(distinct seat)
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    where r.code = '$room_code' and rp.left_at is null;
  "
)"

if [[ "$active_count" != "3" || "$distinct_seats" != "3" ]]; then
  echo "Capacity invariant failed: members=$active_count seats=$distinct_seats" >&2
  exit 1
fi

echo "PASS: one concurrent join succeeded, one returned room_full; members=3 unique_seats=3"
