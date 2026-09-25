import 'dart:async';

import 'package:ai_la_ke_gia_mao/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthDataSource implements AuthRemoteDataSource {
  _FakeAuthDataSource({this.currentUserId});

  @override
  String? currentUserId;
  int signInCalls = 0;
  final signInCompleter = Completer<String?>();

  @override
  Future<String?> signInAnonymously() {
    signInCalls += 1;
    return signInCompleter.future;
  }
}

void main() {
  test('restores an existing session without anonymous sign-in', () async {
    final dataSource = _FakeAuthDataSource(currentUserId: 'restored-user');
    final repository = SupabaseAuthRepository(dataSource);

    final identity = await repository.ensureAuthenticated();

    expect(identity.id, 'restored-user');
    expect(dataSource.signInCalls, 0);
  });

  test('signs in anonymously when no session exists', () async {
    final dataSource = _FakeAuthDataSource();
    final repository = SupabaseAuthRepository(dataSource);
    dataSource.signInCompleter.complete('anonymous-user');

    final identity = await repository.ensureAuthenticated();

    expect(identity.id, 'anonymous-user');
    expect(dataSource.signInCalls, 1);
  });

  test('deduplicates concurrent anonymous sign-in attempts', () async {
    final dataSource = _FakeAuthDataSource();
    final repository = SupabaseAuthRepository(dataSource);

    final first = repository.ensureAuthenticated();
    final second = repository.ensureAuthenticated();
    dataSource.signInCompleter.complete('one-user');

    expect((await first).id, 'one-user');
    expect((await second).id, 'one-user');
    expect(dataSource.signInCalls, 1);
  });

  test('does not sign in again after a successful anonymous session', () async {
    final dataSource = _FakeAuthDataSource();
    final repository = SupabaseAuthRepository(dataSource);
    dataSource.signInCompleter.complete('stable-user');

    await repository.ensureAuthenticated();
    final restored = await repository.ensureAuthenticated();

    expect(restored.id, 'stable-user');
    expect(dataSource.signInCalls, 1);
  });
}
