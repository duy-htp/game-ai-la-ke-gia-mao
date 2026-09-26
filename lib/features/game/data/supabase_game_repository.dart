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

  @override
  Future<GameSnapshot> acknowledgeRole() => _gameRpc('acknowledge_role');

  @override
  Future<GameSnapshot> advanceIfDue() => _gameRpc('advance_game_if_due');

  @override
  Future<GameSnapshot> submitClue(String text) =>
      _gameRpc('submit_clue', params: {'p_text': text});

  @override
  Future<GameSnapshot> setDiscussionReady(bool ready) =>
      _gameRpc('set_discussion_ready', params: {'p_ready': ready});

  @override
  Future<GameSnapshot> submitVote(String targetPlayerId) =>
      _gameRpc('submit_vote', params: {'p_target_player_id': targetPlayerId});

  Future<GameSnapshot> _gameRpc(
    String name, {
    Map<String, Object?>? params,
  }) async {
    try {
      final value = await _client.rpc<Object?>(name, params: params);
      if (value is Map && value['action_error'] != null) {
        throw const InvalidClueAppError();
      }
      return _game(value);
    } on AppError {
      rethrow;
    } on PostgrestException catch (error) {
      throw switch (error.message) {
        'not_current_turn' => const NotCurrentTurnAppError(),
        'turn_expired' => const TurnExpiredAppError(),
        'invalid_clue' => const InvalidClueAppError(),
        'clue_already_submitted' => const ClueAlreadySubmittedAppError(),
        'invalid_vote_target' => const InvalidVoteTargetAppError(),
        'self_vote_not_allowed' => const SelfVoteAppError(),
        'vote_already_submitted' => const VoteAlreadySubmittedAppError(),
        'vote_expired' => const VoteExpiredAppError(),
        _ => const GameOperationAppError(),
      };
    } catch (_) {
      throw const GameOperationAppError();
    }
  }

  GameSnapshot _game(Object? value) {
    if (value is! Map) throw const GameOperationAppError();
    return GameSnapshot.fromJson(Map<String, Object?>.from(value));
  }
}
