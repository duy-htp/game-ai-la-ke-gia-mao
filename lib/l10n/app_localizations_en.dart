// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get gameTitle => 'WHO IS THE IMPOSTOR?';

  @override
  String get gameTagline => 'Read your friends. Keep your secret.';

  @override
  String get createRoom => 'CREATE ROOM';

  @override
  String get joinRoom => 'JOIN ROOM';

  @override
  String get profile => 'Profile';

  @override
  String get shop => 'Shop';

  @override
  String get settings => 'Settings';

  @override
  String get comingSoon => 'This feature is coming in a future milestone.';

  @override
  String get developmentEnvironment => 'DEVELOPMENT BUILD';

  @override
  String get stagingEnvironment => 'STAGING BUILD';

  @override
  String get identityMarkLabel => 'Mysterious mask symbol';

  @override
  String get authInitializing => 'Restoring your player…';

  @override
  String get retry => 'TRY AGAIN';

  @override
  String get chooseYourName => 'CHOOSE YOUR NAME';

  @override
  String get displayName => 'Display name';

  @override
  String get usernameHint => 'Example: Alex';

  @override
  String get chooseAvatar => 'CHOOSE YOUR CHARACTER';

  @override
  String get startPlaying => 'START PLAYING';

  @override
  String avatarOption(int number) {
    return 'Character $number';
  }

  @override
  String playerLevel(int level) {
    return 'Lv. $level';
  }

  @override
  String coinBalance(int coins) {
    return 'Balance: $coins coins';
  }

  @override
  String get errorNetworkUnavailable =>
      'No network connection. Please try again.';

  @override
  String get errorSessionExpired => 'Your session expired. Please start again.';

  @override
  String get errorUnexpected => 'Something went wrong. Please try again.';

  @override
  String get errorConfiguration => 'The server connection is not configured.';

  @override
  String get errorAuthInitialization =>
      'The player session could not be initialized.';

  @override
  String get errorAnonymousSignIn =>
      'A guest session could not be created. Please retry.';

  @override
  String get errorProfileLoad =>
      'Your profile could not be loaded. Please retry.';

  @override
  String get errorUsernameBlank => 'Enter a display name.';

  @override
  String get errorUsernameTooShort =>
      'The name must contain at least 2 characters.';

  @override
  String get errorUsernameTooLong => 'The name cannot exceed 20 characters.';

  @override
  String get errorUsernameInvalidCharacters =>
      'The name contains unsupported characters.';

  @override
  String get errorInvalidAvatar => 'Choose a valid character.';

  @override
  String get errorProfileCreation =>
      'Your profile could not be created. Please retry.';
}
