import '../../../core/errors/app_error.dart';

enum RoomAction { create, join, leave, ready, settings }

sealed class RoomActionState {
  const RoomActionState();
}

final class RoomActionIdle extends RoomActionState {
  const RoomActionIdle();
}

final class RoomActionSubmitting extends RoomActionState {
  const RoomActionSubmitting(this.action);

  final RoomAction action;
}

final class RoomActionError extends RoomActionState {
  const RoomActionError(this.error);

  final AppError error;
}
