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
