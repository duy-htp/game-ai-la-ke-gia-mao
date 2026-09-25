import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_error.dart';
import '../../auth/application/app_session_controller.dart';
import '../domain/game_repository.dart';

sealed class GameActionState {
  const GameActionState();
}

final class GameActionIdle extends GameActionState {
  const GameActionIdle();
}

final class GameActionSubmitting extends GameActionState {
  const GameActionSubmitting();
}

final class GameActionError extends GameActionState {
  const GameActionError(this.error);
  final AppError error;
}

class GameController extends Notifier<GameActionState> {
  String? _requestId;
  @override
  GameActionState build() => const GameActionIdle();
  Future<void> startGame() async {
    if (state is GameActionSubmitting) return;
    final repository = ref.read(gameRepositoryProvider);
    if (repository == null) {
      state = const GameActionError(GameOperationAppError());
      return;
    }
    _requestId ??= const Uuid().v4();
    state = const GameActionSubmitting();
    try {
      final game = await repository.startGame(_requestId!);
      _requestId = null;
      ref.read(appSessionControllerProvider.notifier).setGame(game);
      state = const GameActionIdle();
    } on AppError catch (error) {
      state = GameActionError(error);
    } catch (_) {
      state = const GameActionError(GameOperationAppError());
    }
  }
}

final gameControllerProvider =
    NotifierProvider<GameController, GameActionState>(GameController.new);
