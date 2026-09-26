import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_profile.dart';
import 'game_history.dart';

abstract interface class ProfileRepository {
  Future<PlayerProfile?> fetchOwnProfile();

  Future<PlayerProfile> completeProfile({
    required String username,
    required String avatarId,
  });
  Future<PlayerProfile> updateProfile({
    required String username,
    required String avatarId,
  });
  Future<GameHistoryPage> fetchGameHistory({
    int limit = 20,
    DateTime? beforeFinishedAt,
    String? beforeGameId,
  });
}

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) => null);
