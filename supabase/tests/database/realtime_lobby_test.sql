begin;
select plan(32);

insert into auth.users (id, email)
select id, suffix || '@lobby.test' from (values
  ('20000000-0000-4000-8000-00000000000a'::uuid, 'host'),
  ('20000000-0000-4000-8000-00000000000b'::uuid, 'player-b'),
  ('20000000-0000-4000-8000-00000000000c'::uuid, 'player-c'),
  ('20000000-0000-4000-8000-00000000000d'::uuid, 'outsider')
) users(id, suffix);

set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000a', true);
do $$ begin perform public.complete_profile('Lobby Host', 'avatar_01'); end $$;
select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000b', true);
do $$ begin perform public.complete_profile('Lobby B', 'avatar_02'); end $$;
select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000c', true);
do $$ begin perform public.complete_profile('Lobby C', 'avatar_03'); end $$;
select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000d', true);
do $$ begin perform public.complete_profile('Outsider', 'avatar_04'); end $$;

select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000a', true);
select lives_ok($$ select public.create_room('impostor', 8, '92000000-0000-4000-8000-000000000001') $$, 'Host creates lobby');

set local role postgres;
create temporary table lobby_values as select id, code from public.rooms where created_by = '20000000-0000-4000-8000-00000000000a';
grant select on lobby_values to authenticated;
select is((select is_ready from public.room_players where player_id = '20000000-0000-4000-8000-00000000000a'), false, 'Ready defaults false');
select is((select impostor_count from public.rooms where id = (select id from lobby_values)), 1, 'Default impostor count is one');
select is((select clue_seconds from public.rooms where id = (select id from lobby_values)), 30, 'Default clue timer is 30');
select is((select discussion_seconds from public.rooms where id = (select id from lobby_values)), 90, 'Default discussion timer is 90');
select is((select count(*)::integer from public.categories), 10, 'Ten initial categories are seeded');

set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000b', true);
do $$ begin perform public.join_room((select code from lobby_values)); end $$;
select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000c', true);
do $$ begin perform public.join_room((select code from lobby_values)); end $$;
select is((public.get_current_room()->>'can_start')::boolean, false, 'Three players with unready members cannot start');
select lives_ok($$ select public.set_ready(true) $$, 'Non-host can become ready');
select is((public.set_ready(true)->>'revision')::bigint, (public.get_current_room()->>'revision')::bigint, 'Repeated set_ready true is idempotent');
select is((public.set_ready(false)->'members'->2->>'is_ready')::boolean, false, 'Non-host can become not ready');
do $$ begin perform public.set_ready(true); end $$;

select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000b', true);
do $$ begin perform public.set_ready(true); end $$;
select is((public.get_current_room()->>'can_start')::boolean, true, 'Three players with all non-hosts ready can start');

select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000a', true);
select throws_ok($$ select public.set_ready(true) $$, 'P0001', 'host_ready_not_allowed', 'Host readiness is forbidden and ignored');
select lives_ok($$ select public.update_room_settings(1, 'food', 45, 120) $$, 'Host updates valid settings');
select is((public.get_current_room()->'settings'->>'category_key'), 'food', 'Snapshot contains selected category');
select is((public.get_current_room()->'settings'->>'clue_seconds')::integer, 45, 'Snapshot contains timers');
select is((public.get_current_room()->>'can_start')::boolean, false, 'Settings change resets start eligibility');

set local role postgres;
select is((select count(*)::integer from public.room_players where room_id = (select id from lobby_values) and left_at is null and is_ready), 0, 'Settings change resets every non-host ready state');

set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000b', true);
select throws_ok($$ select public.update_room_settings(1, 'food', 30, 90) $$, 'P0001', 'host_required', 'Non-host cannot update settings');
select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000a', true);
select throws_ok($$ select public.update_room_settings(3, 'food', 30, 90) $$, 'P0001', 'invalid_impostor_count', 'Invalid impostor count rejected');
select throws_ok($$ select public.update_room_settings(1, 'food', 20, 90) $$, 'P0001', 'invalid_clue_time', 'Invalid clue timer rejected');
select throws_ok($$ select public.update_room_settings(1, 'food', 30, 30) $$, 'P0001', 'invalid_discussion_time', 'Invalid discussion timer rejected');
select throws_ok($$ select public.update_room_settings(1, 'missing', 30, 90) $$, 'P0001', 'invalid_category', 'Unknown category rejected');

set local role postgres;
update public.categories set is_active = false where key = 'jobs';
set local role authenticated;
select throws_ok($$ select public.update_room_settings(1, 'jobs', 30, 90) $$, 'P0001', 'invalid_category', 'Inactive category rejected');
select lives_ok($$ select public.update_room_settings(2, 'random', 30, 90) $$, 'Two impostors allowed for capacity eight');
select ok((public.get_current_room()->'settings'->>'category_key') is null, 'Random category is represented by null stable identity');
select ok((public.get_current_room()->'members'->0) ? 'is_ready', 'Safe snapshot contains ready state');
select ok(public.get_current_room() ?& array['revision', 'settings', 'can_start'], 'Safe snapshot contains lobby authority fields');
select ok(not (public.get_current_room() ?| array['created_by', 'create_request_id']), 'Snapshot excludes internal room fields');

select set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-00000000000d', true);
select throws_ok($$ select public.set_ready(true) $$, 'P0001', 'not_room_member', 'Outsider cannot set ready');

set local role postgres;
select ok(not has_table_privilege('authenticated', 'public.rooms', 'SELECT'), 'Rooms remain RPC-only');
select ok(not has_table_privilege('authenticated', 'public.room_players', 'SELECT'), 'Memberships remain RPC-only');
select ok(has_table_privilege('authenticated', 'public.categories', 'SELECT'), 'Public category metadata is intentionally readable');

select * from finish();
rollback;
