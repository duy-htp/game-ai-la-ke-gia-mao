begin;
select plan(40);

create temporary table room_test_values (name text primary key, code text not null);
grant select on room_test_values to authenticated;

insert into auth.users (id, email)
select id, 'room-user-' || suffix || '@example.test'
from (values
  ('10000000-0000-4000-8000-00000000000a'::uuid, 'a'),
  ('10000000-0000-4000-8000-00000000000b'::uuid, 'b'),
  ('10000000-0000-4000-8000-00000000000c'::uuid, 'c'),
  ('10000000-0000-4000-8000-00000000000d'::uuid, 'd'),
  ('10000000-0000-4000-8000-00000000000e'::uuid, 'e'),
  ('10000000-0000-4000-8000-00000000000f'::uuid, 'f'),
  ('10000000-0000-4000-8000-000000000099'::uuid, 'no-profile')
) as users(id, suffix);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000099', true);
select throws_ok(
  $$ select public.create_room('impostor', 6, '90000000-0000-4000-8000-000000000099') $$,
  'P0001', 'profile_required',
  'User without profile cannot create a room'
);

set local role postgres;
select ok(
  not has_function_privilege(
    'anon', 'public.create_room(text,integer,uuid)', 'EXECUTE'
  ),
  'Unauthenticated role cannot execute create_room'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000a', true);
do $$ begin perform public.complete_profile('Host A', 'avatar_01'); end $$;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000b', true);
do $$ begin perform public.complete_profile('Player B', 'avatar_02'); end $$;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000c', true);
do $$ begin perform public.complete_profile('Player C', 'avatar_03'); end $$;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000d', true);
do $$ begin perform public.complete_profile('Player D', 'avatar_04'); end $$;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000e', true);
do $$ begin perform public.complete_profile('Player E', 'avatar_05'); end $$;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000f', true);
do $$ begin perform public.complete_profile('Host F', 'avatar_06'); end $$;

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000a', true);
select throws_ok(
  $$ select public.create_room('impostor', 2, '90000000-0000-4000-8000-000000000002') $$,
  'P0001', 'invalid_max_players', 'maxPlayers 2 is rejected'
);
select throws_ok(
  $$ select public.create_room('impostor', 11, '90000000-0000-4000-8000-000000000011') $$,
  'P0001', 'invalid_max_players', 'maxPlayers 11 is rejected'
);
select throws_ok(
  $$ select public.create_room('trivia', 6, '90000000-0000-4000-8000-000000000012') $$,
  'P0001', 'unsupported_game_type', 'Unsupported game type is rejected'
);
select lives_ok(
  $$ select public.create_room('impostor', 4, '90000000-0000-4000-8000-000000000001') $$,
  'Authenticated profile can create a room'
);

set local role postgres;
insert into room_test_values (name, code)
select 'main', code from public.rooms
where created_by = '10000000-0000-4000-8000-00000000000a';
select throws_ok(
  format(
    'insert into public.rooms (code, host_id, created_by, game_type, status, max_players, create_request_id) values (%L, %L, %L, ''impostor'', ''waiting'', 6, %L)',
    (select code from room_test_values where name = 'main'),
    '10000000-0000-4000-8000-00000000000e',
    '10000000-0000-4000-8000-00000000000e',
    '91000000-0000-4000-8000-00000000000e'
  ),
  '23505',
  'duplicate key value violates unique constraint "rooms_active_code_unique"',
  'Two active rooms cannot share a code'
);
select is(
  (select seat from public.room_players where player_id = '10000000-0000-4000-8000-00000000000a' and left_at is null),
  1, 'Host receives seat 1'
);
select is(
  (select count(*)::integer from public.room_players rp join public.rooms r on r.id = rp.room_id where r.host_id = rp.player_id and rp.left_at is null),
  1, 'Host becomes a room member atomically'
);
select is(
  (select char_length(code) from public.rooms where created_by = '10000000-0000-4000-8000-00000000000a'),
  6, 'Generated room code has exactly 6 characters'
);
select ok(
  (select code ~ '^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$' from public.rooms where created_by = '10000000-0000-4000-8000-00000000000a'),
  'Generated code uses the human-friendly alphabet'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'rooms_active_code_unique' and indexdef like '%UNIQUE%'),
  'Active room code has a unique partial index'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000a', true);
select is(
  (public.create_room('impostor', 4, '90000000-0000-4000-8000-000000000001')->>'room_id')::uuid,
  (public.get_current_room()->>'room_id')::uuid,
  'Create retry with the same request ID returns the same room'
);

set local role postgres;
select is(
  (select count(*)::integer from public.rooms where created_by = '10000000-0000-4000-8000-00000000000a'),
  1, 'Create retry does not create a duplicate room'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000b', true);
select lives_ok(
  format('select public.join_room(%L)', lower((select code from room_test_values where name = 'main'))),
  'Lowercase room code is accepted'
);
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000c', true);
select lives_ok(
  format('select public.join_room(%L)', '  ' || (select code from room_test_values where name = 'main') || '  '),
  'Room code surrounding whitespace is trimmed'
);

set local role postgres;
select is(
  (select seat from public.room_players where player_id = '10000000-0000-4000-8000-00000000000b' and left_at is null),
  2, 'First joiner gets the lowest available seat'
);
select is(
  (select seat from public.room_players where player_id = '10000000-0000-4000-8000-00000000000c' and left_at is null),
  3, 'Second joiner gets the next available seat'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000b', true);
select lives_ok(
  format('select public.join_room(%L)', (select code from room_test_values where name = 'main')),
  'Retrying join for the same active room is idempotent'
);
set local role postgres;
select is(
  (select count(*)::integer from public.room_players where player_id = '10000000-0000-4000-8000-00000000000b' and left_at is null),
  1, 'Join retry does not duplicate membership'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000d', true);
select throws_ok(
  $$ select public.join_room('O0I1L!') $$,
  'P0001', 'invalid_room_code', 'Malformed room code is rejected'
);
select lives_ok(
  format('select public.join_room(%L)', (select code from room_test_values where name = 'main')),
  'A valid profile can join a waiting room'
);
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000e', true);
select throws_ok(
  format('select public.join_room(%L)', (select code from room_test_values where name = 'main')),
  'P0001', 'room_full', 'A full room rejects another joiner'
);
select throws_ok(
  $$ select public.join_room('ZZZZZZ') $$,
  'P0001', 'room_not_found', 'Unknown room code is rejected'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000f', true);
select lives_ok(
  $$ select public.create_room('impostor', 6, '90000000-0000-4000-8000-00000000000f') $$,
  'A second independent room can be created'
);
set local role postgres;
insert into room_test_values (name, code)
select 'second', code from public.rooms
where created_by = '10000000-0000-4000-8000-00000000000f';
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000b', true);
select throws_ok(
  format('select public.join_room(%L)', (select code from room_test_values where name = 'second')),
  'P0001', 'already_in_another_room', 'Player cannot join two active rooms'
);

select throws_ok(
  $$ insert into public.rooms (code, host_id, created_by, game_type, status, max_players, create_request_id) values ('ABC234', auth.uid(), auth.uid(), 'impostor', 'waiting', 6, gen_random_uuid()) $$,
  '42501', 'permission denied for table rooms', 'Client cannot directly insert a room'
);
select throws_ok(
  $$ insert into public.room_players (room_id, player_id, seat) values (gen_random_uuid(), auth.uid(), 1) $$,
  '42501', 'permission denied for table room_players', 'Client cannot directly insert membership'
);
select throws_ok(
  $$ update public.rooms set host_id = auth.uid() $$,
  '42501', 'permission denied for table rooms', 'Client cannot directly change host'
);
select throws_ok(
  $$ select * from public.rooms $$,
  '42501', 'permission denied for table rooms', 'Client cannot enumerate unrelated rooms'
);
select throws_ok(
  $$ select * from public.room_players $$,
  '42501', 'permission denied for table room_players', 'Client cannot inspect unrelated memberships'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000a', true);
select ok(
  not ((public.get_current_room()->'members'->0) ?| array['coins', 'xp', 'level', 'email', 'created_at']),
  'Room snapshot excludes economy and auth/profile-private fields'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000b', true);
select lives_ok($$ select public.leave_room() $$, 'Non-host can leave safely');

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000a', true);
select lives_ok($$ select public.leave_room() $$, 'Host can leave safely');
set local role postgres;
select is(
  (select host_id from public.rooms where created_by = '10000000-0000-4000-8000-00000000000a'),
  '10000000-0000-4000-8000-00000000000c'::uuid,
  'Host transfers deterministically to earliest eligible member'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000c', true);
do $$ begin perform public.leave_room(); end $$;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000d', true);
select lives_ok($$ select public.leave_room() $$, 'Final player can leave safely');
select lives_ok(
  $$ select public.leave_room() $$,
  'Leave retry with no active room is safely idempotent'
);

set local role postgres;
select ok(
  (select status = 'closed' and host_id is null from public.rooms where created_by = '10000000-0000-4000-8000-00000000000a'),
  'Last player leaving closes the room and clears host'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-00000000000e', true);
select throws_ok(
  format('select public.join_room(%L)', (select code from room_test_values where name = 'main')),
  'P0001', 'room_closed', 'Closed room cannot be joined'
);

set local role postgres;
select lives_ok(
  format(
    'insert into public.rooms (code, host_id, created_by, game_type, status, max_players, create_request_id) values (%L, %L, %L, ''impostor'', ''waiting'', 6, %L)',
    (select code from room_test_values where name = 'main'),
    '10000000-0000-4000-8000-00000000000e',
    '10000000-0000-4000-8000-00000000000e',
    '90000000-0000-4000-8000-00000000000e'
  ),
  'A closed room code can be reused by a new active room'
);

select * from finish();
rollback;
