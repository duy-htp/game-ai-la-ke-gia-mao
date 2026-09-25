import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_profile.dart';

abstract interface class ProfileRepository {
  Future<PlayerProfile?> fetchOwnProfile();

  Future<PlayerProfile> completeProfile({
    required String username,
    required String avatarId,
  });
}

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) => null);
