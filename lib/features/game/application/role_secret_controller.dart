import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../domain/game_repository.dart';
import '../domain/player_game_secret.dart';

sealed class RoleSecretState {
  const RoleSecretState();
}

final class RoleSecretLoading extends RoleSecretState {
  const RoleSecretLoading();
}

final class RoleSecretReady extends RoleSecretState {
  const RoleSecretReady(this.secret);
  final PlayerGameSecret secret;
}

final class RoleSecretError extends RoleSecretState {
  const RoleSecretError(this.error);
  final AppError error;
}

class RoleSecretController extends Notifier<RoleSecretState> {
  @override
  RoleSecretState build() {
    Future.microtask(load);
    return const RoleSecretLoading();
  }

  Future<void> load() async {
    final repository = ref.read(gameRepositoryProvider);
    if (repository == null) {
      state = const RoleSecretError(SecretUnavailableAppError());
      return;
    }
    state = const RoleSecretLoading();
    try {
      state = RoleSecretReady(await repository.loadMySecret());
    } on AppError catch (error) {
      state = RoleSecretError(error);
    } catch (_) {
      state = const RoleSecretError(SecretUnavailableAppError());
    }
  }
}

final roleSecretControllerProvider =
    NotifierProvider.autoDispose<RoleSecretController, RoleSecretState>(
      RoleSecretController.new,
    );
