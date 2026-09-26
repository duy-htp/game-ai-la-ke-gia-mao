import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/repository_error_mapper.dart';
import '../domain/player_profile.dart';
import '../domain/game_history.dart';
import '../domain/profile_input_validator.dart';
import '../domain/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PlayerProfile?> fetchOwnProfile() async {
    if (_client.auth.currentUser == null) throw const SessionExpiredAppError();
    try {
      final response = await _client.rpc<Object?>('get_my_profile');
      if (response == null) return null;
      return PlayerProfile.fromJson(Map<String, Object?>.from(response as Map));
    } on AppError {
      rethrow;
    } catch (error) {
      throw RepositoryErrorMapper.profileLoad(error);
    }
  }

  @override
  Future<PlayerProfile> completeProfile({
    required String username,
    required String avatarId,
  }) async {
    final input = ProfileInputValidator.validate(
      username: username,
      avatarId: avatarId,
    );
    try {
      final response = await _client.rpc<Object?>(
        'complete_profile',
        params: {'p_username': input.username, 'p_avatar_id': input.avatarId},
      );
      if (response is! Map) throw const ProfileCreationAppError();
      return PlayerProfile.fromJson(Map<String, Object?>.from(response));
    } on AppError {
      rethrow;
    } catch (error) {
      throw RepositoryErrorMapper.profileCreation(error);
    }
  }

  @override
  Future<PlayerProfile> updateProfile({
    required String username,
    required String avatarId,
  }) async {
    final input = ProfileInputValidator.validate(
      username: username,
      avatarId: avatarId,
    );
    try {
      final response = await _client.rpc<Object?>(
        'update_my_profile',
        params: {'p_username': input.username, 'p_avatar_id': input.avatarId},
      );
      return PlayerProfile.fromJson(
        Map<String, Object?>.from(response! as Map),
      );
    } on AppError {
      rethrow;
    } catch (error) {
      throw RepositoryErrorMapper.profileCreation(error);
    }
  }

  @override
  Future<GameHistoryPage> fetchGameHistory({
    int limit = 20,
    DateTime? beforeFinishedAt,
    String? beforeGameId,
  }) async {
    try {
      final response = await _client.rpc<Object?>(
        'get_my_game_history',
        params: {
          'p_limit': limit,
          'p_before_finished_at': beforeFinishedAt?.toUtc().toIso8601String(),
          'p_before_game_id': beforeGameId,
        },
      );
      return GameHistoryPage.fromJson(
        Map<String, Object?>.from(response! as Map),
      );
    } catch (error) {
      throw RepositoryErrorMapper.profileLoad(error);
    }
  }
}
