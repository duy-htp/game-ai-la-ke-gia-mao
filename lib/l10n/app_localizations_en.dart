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
  String get errorNetworkUnavailable =>
      'No network connection. Please try again.';

  @override
  String get errorSessionExpired => 'Your session expired. Please start again.';

  @override
  String get errorUnexpected => 'Something went wrong. Please try again.';
}
