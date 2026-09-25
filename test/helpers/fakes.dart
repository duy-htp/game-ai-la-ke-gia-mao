import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_identity.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/player_profile.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';

final sampleProfile = PlayerProfile(
  id: '00000000-0000-4000-8000-000000000001',
  username: 'Dũng',
  avatarId: 'avatar_01',
  coins: 0,
  xp: 0,
  level: 1,
  createdAt: DateTime.utc(2026, 9, 24),
  updatedAt: DateTime.utc(2026, 9, 24),
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.error});

  final Object? error;
  int calls = 0;

  @override
  Future<AuthIdentity> ensureAuthenticated() async {
    calls += 1;
    if (error case final error?) throw error;
    return const AuthIdentity(id: '00000000-0000-4000-8000-000000000001');
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile, this.fetchError, this.completeError});

  PlayerProfile? profile;
  final Object? fetchError;
  final Object? completeError;
  int fetchCalls = 0;
  int completeCalls = 0;
  String? submittedUsername;
  String? submittedAvatarId;

  @override
  Future<PlayerProfile?> fetchOwnProfile() async {
    fetchCalls += 1;
    if (fetchError case final error?) throw error;
    return profile;
  }

  @override
  Future<PlayerProfile> completeProfile({
    required String username,
    required String avatarId,
  }) async {
    completeCalls += 1;
    submittedUsername = username;
    submittedAvatarId = avatarId;
    if (completeError case final error?) throw error;
    return profile ?? sampleProfile;
  }
}
