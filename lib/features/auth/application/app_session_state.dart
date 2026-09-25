import '../../../core/errors/app_error.dart';
import '../../profile/domain/player_profile.dart';
import '../../room/domain/room_snapshot.dart';
import '../domain/auth_identity.dart';

sealed class AppSessionState {
  const AppSessionState();
}

final class AppSessionInitializing extends AppSessionState {
  const AppSessionInitializing();
}

final class AppSessionNeedsProfile extends AppSessionState {
  const AppSessionNeedsProfile({
    required this.identity,
    this.isSubmitting = false,
    this.submissionError,
  });

  final AuthIdentity identity;
  final bool isSubmitting;
  final AppError? submissionError;

  AppSessionNeedsProfile copyWith({
    bool? isSubmitting,
    AppError? submissionError,
    bool clearError = false,
  }) {
    return AppSessionNeedsProfile(
      identity: identity,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionError: clearError
          ? null
          : submissionError ?? this.submissionError,
    );
  }
}

final class AppSessionReady extends AppSessionState {
  const AppSessionReady(this.profile, {this.room});

  final PlayerProfile profile;
  final RoomSnapshot? room;
}

final class AppSessionRecoverableError extends AppSessionState {
  const AppSessionRecoverableError(this.error);

  final AppError error;
}

final class AppSessionFatalConfigurationError extends AppSessionState {
  const AppSessionFatalConfigurationError(this.error);

  final AppError error;
}
