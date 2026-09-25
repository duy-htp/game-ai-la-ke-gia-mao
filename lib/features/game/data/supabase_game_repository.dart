import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../domain/game_repository.dart';
import '../domain/game_snapshot.dart';
import '../domain/player_game_secret.dart';

class SupabaseGameRepository implements GameRepository {
  SupabaseGameRepository(this._client);
  final SupabaseClient _client;
  @override
  Future<GameSnapshot> startGame(String requestId) async {
    try {
      return _game(
        await _client.rpc<Object?>(
          'start_game',
          params: {'p_request_id': requestId},
        ),
      );
    } catch (_) {
      throw const GameOperationAppError();
    }
  }

  @override
  Future<GameSnapshot?> loadCurrentGame() async {
    try {
      final value = await _client.rpc<Object?>('get_current_game');
      return value == null ? null : _game(value);
    } catch (_) {
      throw const GameOperationAppError();
    }
  }

  @override
  Future<PlayerGameSecret> loadMySecret() async {
    try {
      final value = await _client.rpc<Object?>('get_my_game_secret');
      if (value is! Map) throw const SecretUnavailableAppError();
      return PlayerGameSecret.fromJson(Map<String, Object?>.from(value));
    } catch (error) {
      if (error is AppError) rethrow;
      throw const SecretUnavailableAppError();
    }
  }

  GameSnapshot _game(Object? value) {
    if (value is! Map) throw const GameOperationAppError();
    return GameSnapshot.fromJson(Map<String, Object?>.from(value));
  }
}
