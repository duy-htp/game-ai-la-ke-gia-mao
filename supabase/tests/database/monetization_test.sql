begin;select plan(26);
insert into auth.users(id,email)values
('84000000-0000-4000-8000-000000000001','money1@test'),('84000000-0000-4000-8000-000000000002','money2@test');
insert into profiles(id,username,avatar_id)values
('84000000-0000-4000-8000-000000000001','Money One','avatar_01'),('84000000-0000-4000-8000-000000000002','Money Two','avatar_02');

set local role authenticated;select set_config('request.jwt.claim.sub','84000000-0000-4000-8000-000000000001',true);select set_config('request.jwt.claim.role','authenticated',true);
select is((get_my_monetization_state()->>'remove_ads')::boolean,false,'Remove Ads defaults false');
select is((get_my_monetization_state()->>'rewarded_remaining_today')::int,3,'Three daily rewards available');
select throws_ok($$select*from player_entitlements$$,'42501',null,'Entitlements have no direct read');
select throws_ok($$select*from ad_rewards$$,'42501',null,'Ad ledger has no direct read');
select throws_ok($$insert into player_entitlements(player_id,entitlement_type,source,source_transaction_id,active,provider_occurred_at,granted_at)values('84000000-0000-4000-8000-000000000001','remove_ads','fake','tx1',true,now(),now())$$,'42501',null,'Client cannot activate entitlement');
select throws_ok($$insert into ad_rewards(player_id,provider,provider_event_id,status,granted_at)values('84000000-0000-4000-8000-000000000001','fake','event-0001','granted',now())$$,'42501',null,'Client cannot insert ad reward');
select throws_ok($$select process_verified_ad_reward('84000000-0000-4000-8000-000000000001','test','event-0001')$$,'42501',null,'Client cannot call verification function');
select throws_ok($$select process_verified_entitlement_event('84000000-0000-4000-8000-000000000001','test','event-0002','tx1',true,now())$$,'42501',null,'Client cannot call entitlement verifier');
select throws_ok($$update profiles set coins=99999 where id='84000000-0000-4000-8000-000000000001'$$,'42501',null,'Direct coins mutation remains denied');

set local role postgres;select set_config('request.jwt.claim.role','service_role',true);
select is(process_verified_ad_reward('84000000-0000-4000-8000-000000000001','test','reward-0001')->>'status','granted','First verified reward granted');
select is((select coins from profiles where id='84000000-0000-4000-8000-000000000001'),50,'First reward adds exactly 50');
select is(process_verified_ad_reward('84000000-0000-4000-8000-000000000001','test','reward-0001')->>'status','granted','Duplicate event is idempotent');
select is((select coins from profiles where id='84000000-0000-4000-8000-000000000001'),50,'Duplicate does not add coins');
select is(process_verified_ad_reward('84000000-0000-4000-8000-000000000001','test','reward-0002')->>'status','granted','Second reward granted');
select is(process_verified_ad_reward('84000000-0000-4000-8000-000000000001','test','reward-0003')->>'status','granted','Third reward granted');
select is(process_verified_ad_reward('84000000-0000-4000-8000-000000000001','test','reward-0004')->>'status','daily_limit_reached','Fourth reward rejected');
select is((select coins from profiles where id='84000000-0000-4000-8000-000000000001'),150,'Daily rewards total exactly 150');
select is((select sum(coins_delta)::int from ad_rewards where player_id='84000000-0000-4000-8000-000000000001'and status='granted'),150,'Coins match granted ledger');
select is(process_verified_entitlement_event('84000000-0000-4000-8000-000000000001','revenuecat','purchase-0001','original-tx-1',true,'2026-09-28T10:00:00Z')->>'active','true','Verified purchase activates Remove Ads');
select is(process_verified_entitlement_event('84000000-0000-4000-8000-000000000001','revenuecat','purchase-0001','original-tx-1',true,'2026-09-28T10:00:00Z')->>'duplicate','true','Duplicate purchase event safe');
select is((select count(*)::int from player_entitlements where player_id='84000000-0000-4000-8000-000000000001'),1,'One logical entitlement row');
select is(process_verified_entitlement_event('84000000-0000-4000-8000-000000000001','revenuecat','old-revoke-1','original-tx-1',false,'2026-09-28T09:00:00Z')->>'active','true','Older revoke cannot regress entitlement');
select is(process_verified_entitlement_event('84000000-0000-4000-8000-000000000001','revenuecat','new-revoke-1','original-tx-1',false,'2026-09-28T11:00:00Z')->>'active','false','Newer verified revoke applies');

set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','84000000-0000-4000-8000-000000000001',true);
select is((get_my_monetization_state()->>'rewarded_used_today')::int,3,'Caller sees authoritative daily usage');
select set_config('request.jwt.claim.sub','84000000-0000-4000-8000-000000000002',true);
select is((get_my_monetization_state()->>'rewarded_used_today')::int,0,'Other caller cannot see first player ledger');
select is((get_my_monetization_state()->>'remove_ads')::boolean,false,'Other caller cannot see first player entitlement');
select*from finish();rollback;
