import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/repository_error_mapper.dart';
import '../domain/auth_identity.dart';
import '../domain/auth_repository.dart';

abstract interface class AuthRemoteDataSource {
  String? get currentUserId;

  Future<String?> signInAnonymously();
}

class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  SupabaseAuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentSession?.user.id;

  @override
  Future<String?> signInAnonymously() async {
    final response = await _client.auth.signInAnonymously();
    return response.user?.id;
  }
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._dataSource);

  final AuthRemoteDataSource _dataSource;
  Future<AuthIdentity>? _pendingAuthentication;
  AuthIdentity? _authenticatedIdentity;

  @override
  Future<AuthIdentity> ensureAuthenticated() {
    final cachedIdentity = _authenticatedIdentity;
    if (cachedIdentity != null) return Future.value(cachedIdentity);

    final restoredUserId = _dataSource.currentUserId;
    if (restoredUserId != null) {
      final identity = AuthIdentity(id: restoredUserId);
      _authenticatedIdentity = identity;
      return Future.value(identity);
    }

    return _pendingAuthentication ??= _signInAnonymously().whenComplete(
      () => _pendingAuthentication = null,
    );
  }

  Future<AuthIdentity> _signInAnonymously() async {
    try {
      final userId = await _dataSource.signInAnonymously();
      if (userId == null) throw const AnonymousSignInAppError();
      final identity = AuthIdentity(id: userId);
      _authenticatedIdentity = identity;
      return identity;
    } on AppError {
      rethrow;
    } catch (error) {
      throw RepositoryErrorMapper.auth(error);
    }
  }
}
