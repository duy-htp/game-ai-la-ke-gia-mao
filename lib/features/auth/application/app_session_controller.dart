import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_error.dart';
import '../../profile/domain/profile_input_validator.dart';
import '../../profile/domain/profile_repository.dart';
import '../../room/domain/room_repository.dart';
import '../../room/domain/room_snapshot.dart';
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
    if (authRepository == null ||
        profileRepository == null ||
        roomRepository == null) {
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
      state = AppSessionReady(profile, room: room);
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
      state = AppSessionReady(current.profile, room: room);
    }
  }

  void clearRoom() {
    final current = state;
    if (current is AppSessionReady) {
      state = AppSessionReady(current.profile);
    }
  }
}

final appSessionControllerProvider =
    NotifierProvider<AppSessionController, AppSessionState>(
      AppSessionController.new,
    );
