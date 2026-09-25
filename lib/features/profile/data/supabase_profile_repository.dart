import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/repository_error_mapper.dart';
import '../domain/player_profile.dart';
import '../domain/profile_input_validator.dart';
import '../domain/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PlayerProfile?> fetchOwnProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const SessionExpiredAppError();
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (response == null) return null;
      return PlayerProfile.fromJson(response);
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
}
