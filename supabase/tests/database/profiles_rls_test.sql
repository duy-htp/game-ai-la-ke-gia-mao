begin;

select plan(22);

insert into auth.users (id, email)
values
  ('00000000-0000-4000-8000-00000000000a', 'user-a@example.test'),
  ('00000000-0000-4000-8000-00000000000b', 'user-b@example.test');

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-00000000000a',
  true
);

select lives_ok(
  $$ select public.complete_profile('  Dũng  ', 'avatar_01') $$,
  'User A can complete their own profile'
);
select is(
  (select username from public.profiles),
  'Dũng',
  'Username is trimmed while preserving Vietnamese diacritics'
);
select is((select coins from public.profiles), 0, 'Initial coins are zero');
select is((select xp from public.profiles), 0, 'Initial XP is zero');
select is((select level from public.profiles), 1, 'Initial level is one');

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-00000000000b',
  true
);
select lives_ok(
  $$ select public.complete_profile('Test B', 'avatar_02') $$,
  'User B can complete their own profile'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-00000000000a',
  true
);
select is(
  (select count(*)::integer from public.profiles),
  1,
  'User A sees exactly their own profile'
);
select is(
  (
    select count(*)::integer
    from public.profiles
    where id = '00000000-0000-4000-8000-00000000000b'
  ),
  0,
  'User A cannot read User B profile'
);

select throws_ok(
  $$
    insert into public.profiles (id, username, avatar_id, coins, xp, level)
    values (
      '00000000-0000-4000-8000-00000000000b',
      'Attacker',
      'avatar_01',
      999999,
      999999,
      999
    )
  $$,
  '42501',
  'permission denied for table profiles',
  'User A cannot create or set economy for User B'
);

select is(
  (
    select pg_get_function_identity_arguments(p.oid)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'complete_profile'
  ),
  'p_username text, p_avatar_id text',
  'RPC accepts no user ID or economy arguments'
);

select throws_ok(
  $$ update public.profiles set coins = 99 where id = auth.uid() $$,
  '42501',
  'permission denied for table profiles',
  'Authenticated client cannot update coins'
);
select throws_ok(
  $$ update public.profiles set xp = 99 where id = auth.uid() $$,
  '42501',
  'permission denied for table profiles',
  'Authenticated client cannot update XP'
);
select throws_ok(
  $$ update public.profiles set level = 99 where id = auth.uid() $$,
  '42501',
  'permission denied for table profiles',
  'Authenticated client cannot update level'
);

select throws_ok(
  $$ select public.complete_profile('Test User', 'avatar_99') $$,
  'P0001',
  'Invalid avatar',
  'Invalid avatar is rejected'
);
select throws_ok(
  $$ select public.complete_profile(' ', 'avatar_01') $$,
  'P0001',
  'Username must contain at least 2 characters',
  'Blank username is rejected'
);
select throws_ok(
  $$ select public.complete_profile('This name is much too long', 'avatar_01') $$,
  'P0001',
  'Username cannot exceed 20 characters',
  'Long username is rejected'
);
select throws_ok(
  E' select public.complete_profile(''Bad\nName'', ''avatar_01'') ',
  'P0001',
  'Username contains control characters',
  'Control characters are rejected'
);

select lives_ok(
  $$ select public.complete_profile('Changed Name', 'avatar_03') $$,
  'A retried profile creation is safe'
);
select is(
  (select username from public.profiles),
  'Dũng',
  'A retry does not overwrite an existing profile'
);

select ok(
  not has_table_privilege('authenticated', 'public.profiles', 'INSERT'),
  'Authenticated role has no direct INSERT grant'
);
select ok(
  not has_table_privilege('authenticated', 'public.profiles', 'UPDATE'),
  'Authenticated role has no direct UPDATE grant'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.complete_profile(text,text)',
    'EXECUTE'
  ),
  'Unauthenticated role cannot execute complete_profile'
);

select * from finish();
rollback;
