import 'dart:io';

import 'app_error.dart';

abstract final class RepositoryErrorMapper {
  static AppError auth(Object error) {
    if (error is SocketException) return const NetworkAppError();
    return const AnonymousSignInAppError();
  }

  static AppError profileLoad(Object error) {
    if (error is SocketException) return const NetworkAppError();
    return const ProfileLoadAppError();
  }

  static AppError profileCreation(Object error) {
    if (error is SocketException) return const NetworkAppError();
    return const ProfileCreationAppError();
  }
}
