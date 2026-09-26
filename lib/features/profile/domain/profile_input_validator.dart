import '../../../core/errors/app_error.dart';
import 'avatar_catalog.dart';

class ValidatedProfileInput {
  const ValidatedProfileInput({required this.username, required this.avatarId});

  final String username;
  final String avatarId;
}

abstract final class ProfileInputValidator {
  static final _controlCharacters = RegExp(r'[\x00-\x1F\x7F-\x9F]');

  static ValidatedProfileInput validate({
    required String username,
    required String avatarId,
  }) {
    final trimmedUsername = username.trim();
    if (_controlCharacters.hasMatch(trimmedUsername)) {
      throw const InvalidUsernameAppError(UsernameErrorReason.controlCharacter);
    }
    final normalizedUsername = trimmedUsername.replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedUsername.isEmpty) {
      throw const InvalidUsernameAppError(UsernameErrorReason.blank);
    }
    if (normalizedUsername.runes.length < 2) {
      throw const InvalidUsernameAppError(UsernameErrorReason.tooShort);
    }
    if (normalizedUsername.runes.length > 20) {
      throw const InvalidUsernameAppError(UsernameErrorReason.tooLong);
    }
    if (!AvatarCatalog.ids.contains(avatarId)) {
      throw const InvalidAvatarAppError();
    }
    return ValidatedProfileInput(
      username: normalizedUsername,
      avatarId: avatarId,
    );
  }
}
