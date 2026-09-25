import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_identity.dart';

abstract interface class AuthRepository {
  Future<AuthIdentity> ensureAuthenticated();
}

final authRepositoryProvider = Provider<AuthRepository?>((ref) => null);
