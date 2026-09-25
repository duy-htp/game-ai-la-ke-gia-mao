sealed class AppError implements Exception {
  const AppError(this.code);

  final String code;
}

final class NetworkAppError extends AppError {
  const NetworkAppError() : super('network_unavailable');
}

final class SessionExpiredAppError extends AppError {
  const SessionExpiredAppError() : super('session_expired');
}

final class UnexpectedAppError extends AppError {
  const UnexpectedAppError() : super('unexpected');
}

final class MissingConfigurationAppError extends AppError {
  const MissingConfigurationAppError() : super('configuration_missing');
}

final class InvalidConfigurationAppError extends AppError {
  const InvalidConfigurationAppError() : super('configuration_invalid');
}

final class AuthInitializationAppError extends AppError {
  const AuthInitializationAppError() : super('auth_initialization_failed');
}

final class AnonymousSignInAppError extends AppError {
  const AnonymousSignInAppError() : super('anonymous_sign_in_failed');
}

final class ProfileLoadAppError extends AppError {
  const ProfileLoadAppError() : super('profile_load_failed');
}

final class InvalidUsernameAppError extends AppError {
  const InvalidUsernameAppError(this.reason) : super('invalid_username');

  final UsernameErrorReason reason;
}

enum UsernameErrorReason { blank, tooShort, tooLong, controlCharacter }

final class InvalidAvatarAppError extends AppError {
  const InvalidAvatarAppError() : super('invalid_avatar');
}

final class ProfileCreationAppError extends AppError {
  const ProfileCreationAppError() : super('profile_creation_failed');
}
