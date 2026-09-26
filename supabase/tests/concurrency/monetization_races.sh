#!/usr/bin/env bash
set -euo pipefail
db="supabase_db_game-ai-la-ke-gia-mao"
player="85000000-0000-4000-8000-000000000001"
run_service(){ docker exec "$db" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -Atq -c "begin;select set_config('request.jwt.claim.role','service_role',true);$1;commit;"; }
cleanup(){ docker exec "$db" psql -U postgres -d postgres -q -c "delete from monetization_events where player_id='$player';delete from player_entitlements where player_id='$player';delete from ad_rewards where player_id='$player';delete from profiles where id='$player';delete from auth.users where id='$player';" >/dev/null 2>&1||true;rm -f /tmp/money_race_*; }
trap cleanup EXIT
docker exec "$db" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -c "insert into auth.users(id,email)values('$player','race@money.test');insert into profiles(id,username,avatar_id)values('$player','Money Race','avatar_01');"
run_service "select process_verified_ad_reward('$player','test','race-reward-0001');select process_verified_ad_reward('$player','test','race-reward-0002');" >/dev/null
run_service "select process_verified_ad_reward('$player','test','race-reward-0003');" >/tmp/money_race_reward1 2>&1&a=$!
run_service "select process_verified_ad_reward('$player','test','race-reward-0004');" >/tmp/money_race_reward2 2>&1&b=$!
wait "$a";wait "$b"
read -r granted coins <<<"$(docker exec "$db" psql -U postgres -d postgres -Atq -F ' ' -c "select count(*)filter(where status='granted'),(select coins from profiles where id='$player')from ad_rewards where player_id='$player'")"
[[ "$granted $coins" == "3 150" ]]||{ echo "reward race failed: grants=$granted coins=$coins";exit 1; }
run_service "select process_verified_entitlement_event('$player','revenuecat','race-purchase-0001','race-original-tx',true,clock_timestamp());" >/tmp/money_race_ent1 2>&1&a=$!
run_service "select process_verified_entitlement_event('$player','revenuecat','race-purchase-0001','race-original-tx',true,clock_timestamp());" >/tmp/money_race_ent2 2>&1&b=$!
wait "$a";wait "$b"
read -r entitlements events active <<<"$(docker exec "$db" psql -U postgres -d postgres -Atq -F ' ' -c "select (select count(*)from player_entitlements where player_id='$player'),(select count(*)from monetization_events where player_id='$player'),(select active from player_entitlements where player_id='$player')")"
[[ "$entitlements $events $active" == "1 1 t" ]]||{ echo "entitlement race failed: $entitlements $events $active";exit 1; }
echo "PASS: daily reward race capped at 3/+150 and duplicate purchase produced one active entitlement"
