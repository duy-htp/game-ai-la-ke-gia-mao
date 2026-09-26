import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_error.dart';
import '../../profile/domain/profile_input_validator.dart';
import '../../profile/domain/player_profile.dart';
import '../../profile/domain/profile_repository.dart';
import '../../room/domain/room_repository.dart';
import '../../room/domain/room_snapshot.dart';
import '../../game/domain/game_repository.dart';
import '../../game/domain/game_snapshot.dart';
import '../domain/auth_repository.dart';
import 'app_session_state.dart';

class AppSessionController extends Notifier<AppSessionState> {
  Future<void>? _pendingInitialization;

  @override
  AppSessionState build() => const AppSessionInitializing();

  Future<void> initialize() {
    return _pendingInitialization ??= _initialize().whenComplete(
      () => _pendingInitialization = null,
    );
  }

  Future<void> _initialize() async {
    state = const AppSessionInitializing();
    final config = ref.read(appConfigProvider);
    try {
      config.requireSupabaseConfiguration();
    } on AppError catch (error) {
      state = AppSessionFatalConfigurationError(error);
      return;
    }

    final authRepository = ref.read(authRepositoryProvider);
    final profileRepository = ref.read(profileRepositoryProvider);
    final roomRepository = ref.read(roomRepositoryProvider);
    final gameRepository = ref.read(gameRepositoryProvider);
    if (authRepository == null ||
        profileRepository == null ||
        roomRepository == null ||
        gameRepository == null) {
      state = const AppSessionFatalConfigurationError(
        AuthInitializationAppError(),
      );
      return;
    }

    try {
      final identity = await authRepository.ensureAuthenticated();
      final profile = await profileRepository.fetchOwnProfile();
      if (profile == null) {
        state = AppSessionNeedsProfile(identity: identity);
        return;
      }
      final room = await roomRepository.loadCurrentRoom();
      final game = room == null ? null : await gameRepository.loadCurrentGame();
      state = AppSessionReady(profile, room: room, game: game);
    } on AppError catch (error) {
      state = AppSessionRecoverableError(error);
    } catch (_) {
      state = const AppSessionRecoverableError(UnexpectedAppError());
    }
  }

  Future<void> retry() => initialize();

  Future<void> completeProfile({
    required String username,
    required String avatarId,
  }) async {
    final current = state;
    if (current is! AppSessionNeedsProfile || current.isSubmitting) return;

    try {
      final input = ProfileInputValidator.validate(
        username: username,
        avatarId: avatarId,
      );
      state = current.copyWith(isSubmitting: true, clearError: true);
      final repository = ref.read(profileRepositoryProvider);
      if (repository == null) throw const ProfileCreationAppError();
      final profile = await repository.completeProfile(
        username: input.username,
        avatarId: input.avatarId,
      );
      state = AppSessionReady(profile);
    } on AppError catch (error) {
      state = current.copyWith(submissionError: error);
    } catch (_) {
      state = current.copyWith(
        submissionError: const ProfileCreationAppError(),
      );
    }
  }

  void setRoom(RoomSnapshot room) {
    final current = state;
    if (current is AppSessionReady) {
      if (current.room case final existing?
          when existing.roomId == room.roomId &&
              existing.revision > room.revision) {
        return;
      }
      state = AppSessionReady(current.profile, room: room, game: current.game);
    }
  }

  void setProfile(PlayerProfile profile) {
    final current = state;
    if (current is AppSessionReady) {
      if (current.profile == profile) return;
      state = AppSessionReady(profile, room: current.room, game: current.game);
    }
  }

  void clearRoom() {
    final current = state;
    if (current is AppSessionReady) {
      state = AppSessionReady(current.profile);
    }
  }

  void setGame(GameSnapshot? game) {
    final current = state;
    if (current is AppSessionReady) {
      final existing = current.game;
      if (game != null &&
          existing != null &&
          existing.gameId == game.gameId &&
          existing.revision > game.revision) {
        return;
      }
      state = AppSessionReady(current.profile, room: current.room, game: game);
    }
  }

  void applyRecovered({
    required RoomSnapshot? room,
    required GameSnapshot? game,
  }) {
    final current = state;
    if (current is! AppSessionReady) return;
    final existingRoom = current.room;
    if (room != null &&
        existingRoom != null &&
        room.roomId == existingRoom.roomId &&
        room.revision < existingRoom.revision) {
      return;
    }
    final existingGame = current.game;
    if (game != null &&
        existingGame != null &&
        game.gameId == existingGame.gameId &&
        game.revision < existingGame.revision) {
      return;
    }
    state = AppSessionReady(current.profile, room: room, game: game);
  }
}

final appSessionControllerProvider =
    NotifierProvider<AppSessionController, AppSessionState>(
      AppSessionController.new,
    );
