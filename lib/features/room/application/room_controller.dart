import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_error.dart';
import '../../auth/application/app_session_controller.dart';
import '../domain/game_type.dart';
import '../domain/room_code.dart';
import '../domain/room_repository.dart';
import '../domain/lobby_settings.dart';
import 'room_action_state.dart';

final createRequestIdProvider = Provider<String Function()>(
  (ref) => const Uuid().v4,
);

class RoomController extends Notifier<RoomActionState> {
  String? _pendingCreateRequestId;

  @override
  RoomActionState build() => const RoomActionIdle();

  Future<void> createRoom({int maxPlayers = 6}) async {
    if (state is RoomActionSubmitting) return;
    if (maxPlayers < 3 || maxPlayers > 10) {
      state = const RoomActionError(InvalidMaxPlayersAppError());
      return;
    }
    final repository = ref.read(roomRepositoryProvider);
    if (repository == null) {
      state = const RoomActionError(RoomOperationAppError());
      return;
    }
    _pendingCreateRequestId ??= ref.read(createRequestIdProvider)();
    state = const RoomActionSubmitting(RoomAction.create);
    try {
      final room = await repository.createRoom(
        gameType: GameType.impostor,
        maxPlayers: maxPlayers,
        requestId: _pendingCreateRequestId!,
      );
      _pendingCreateRequestId = null;
      ref.read(appSessionControllerProvider.notifier).setRoom(room);
      state = const RoomActionIdle();
    } on AppError catch (error) {
      state = RoomActionError(error);
    } catch (_) {
      state = const RoomActionError(RoomOperationAppError());
    }
  }

  Future<void> joinRoom(String input) async {
    if (state is RoomActionSubmitting) return;
    final repository = ref.read(roomRepositoryProvider);
    if (repository == null) {
      state = const RoomActionError(RoomOperationAppError());
      return;
    }
    try {
      final code = RoomCode.parse(input);
      state = const RoomActionSubmitting(RoomAction.join);
      final room = await repository.joinRoom(code);
      ref.read(appSessionControllerProvider.notifier).setRoom(room);
      state = const RoomActionIdle();
    } on AppError catch (error) {
      state = RoomActionError(error);
    } catch (_) {
      state = const RoomActionError(RoomOperationAppError());
    }
  }

  Future<void> leaveRoom() async {
    if (state is RoomActionSubmitting) return;
    final repository = ref.read(roomRepositoryProvider);
    if (repository == null) {
      state = const RoomActionError(RoomOperationAppError());
      return;
    }
    state = const RoomActionSubmitting(RoomAction.leave);
    try {
      await repository.leaveRoom();
      ref.read(appSessionControllerProvider.notifier).clearRoom();
      state = const RoomActionIdle();
    } on AppError catch (error) {
      state = RoomActionError(error);
    } catch (_) {
      state = const RoomActionError(RoomOperationAppError());
    }
  }

  Future<void> setReady(bool value) async {
    if (state is RoomActionSubmitting) return;
    final repository = ref.read(roomRepositoryProvider);
    if (repository == null) return;
    state = const RoomActionSubmitting(RoomAction.ready);
    try {
      final room = await repository.setReady(value);
      ref.read(appSessionControllerProvider.notifier).setRoom(room);
      state = const RoomActionIdle();
    } on AppError catch (error) {
      state = RoomActionError(error);
    }
  }

  Future<void> updateSettings(LobbySettings settings) async {
    if (state is RoomActionSubmitting) return;
    final repository = ref.read(roomRepositoryProvider);
    if (repository == null) return;
    state = const RoomActionSubmitting(RoomAction.settings);
    try {
      final room = await repository.updateSettings(settings);
      ref.read(appSessionControllerProvider.notifier).setRoom(room);
      state = const RoomActionIdle();
    } on AppError catch (error) {
      state = RoomActionError(error);
    }
  }

  void clearError() => state = const RoomActionIdle();
}

final roomControllerProvider =
    NotifierProvider<RoomController, RoomActionState>(RoomController.new);
