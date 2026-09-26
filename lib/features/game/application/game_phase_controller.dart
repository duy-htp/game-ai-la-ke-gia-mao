import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../domain/game_snapshot.dart';
import '../domain/game_repository.dart';

sealed class GamePhaseActionState {
  const GamePhaseActionState();
}

final class GamePhaseIdle extends GamePhaseActionState {
  const GamePhaseIdle();
}

final class GamePhaseSubmitting extends GamePhaseActionState {
  const GamePhaseSubmitting();
}

final class GamePhaseFailure extends GamePhaseActionState {
  const GamePhaseFailure(this.error);
  final AppError error;
}

class GamePhaseController extends Notifier<GamePhaseActionState> {
  bool _advancing = false;

  @override
  GamePhaseActionState build() => const GamePhaseIdle();

  Future<void> acknowledgeRole() =>
      _perform((repository) => repository.acknowledgeRole());

  Future<void> submitClue(String text) =>
      _perform((repository) => repository.submitClue(text.trim()));

  Future<void> setDiscussionReady(bool ready) =>
      _perform((repository) => repository.setDiscussionReady(ready));

  Future<void> submitVote(String targetPlayerId) =>
      _perform((repository) => repository.submitVote(targetPlayerId));

  Future<void> submitFinalGuess(String choiceId) =>
      _perform((repository) => repository.submitFinalGuess(choiceId));

  Future<void> playAgain() async {
    if (state is GamePhaseSubmitting) return;
    final repository = ref.read(gameRepositoryProvider);
    if (repository == null) return;
    state = const GamePhaseSubmitting();
    try {
      final room = await repository.playAgain();
      ref.read(appSessionControllerProvider.notifier).setRoom(room);
      ref.read(appSessionControllerProvider.notifier).setGame(null);
      state = const GamePhaseIdle();
    } on AppError catch (error) {
      state = GamePhaseFailure(error);
    }
  }

  Future<void> advanceIfDue() async {
    if (_advancing) return;
    _advancing = true;
    try {
      await _perform(
        (repository) => repository.advanceIfDue(),
        showBusy: false,
      );
    } finally {
      _advancing = false;
    }
  }

  Future<void> refresh() async {
    final repository = ref.read(gameRepositoryProvider);
    if (repository == null) return;
    try {
      final game = await repository.loadCurrentGame();
      if (game != null) _apply(game);
    } catch (_) {}
  }

  Future<void> _perform(
    Future<GameSnapshot> Function(GameRepository repository) operation, {
    bool showBusy = true,
  }) async {
    if (showBusy && state is GamePhaseSubmitting) return;
    final repository = ref.read(gameRepositoryProvider);
    if (repository == null) {
      state = const GamePhaseFailure(GameOperationAppError());
      return;
    }
    if (showBusy) state = const GamePhaseSubmitting();
    try {
      final game = await operation(repository);
      _apply(game);
      state = const GamePhaseIdle();
    } on AppError catch (error) {
      state = GamePhaseFailure(error);
    } catch (_) {
      state = const GamePhaseFailure(GameOperationAppError());
    }
  }

  void _apply(GameSnapshot game) {
    final current = ref.read(appSessionControllerProvider);
    final previous = current is AppSessionReady ? current.game : null;
    if (previous?.gameId == game.gameId &&
        previous?.revision == game.revision &&
        previous?.status == game.status) {
      return;
    }
    ref.read(appSessionControllerProvider.notifier).setGame(game);
  }
}

final gamePhaseControllerProvider =
    NotifierProvider<GamePhaseController, GamePhaseActionState>(
      GamePhaseController.new,
    );
