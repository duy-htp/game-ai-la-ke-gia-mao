import '../../l10n/app_localizations.dart';
import 'app_error.dart';

abstract final class ErrorMessageMapper {
  static String localize(AppError error, AppLocalizations localizations) {
    return switch (error) {
      NetworkAppError() => localizations.errorNetworkUnavailable,
      SessionExpiredAppError() => localizations.errorSessionExpired,
      UnexpectedAppError() => localizations.errorUnexpected,
      MissingConfigurationAppError() ||
      InvalidConfigurationAppError() => localizations.errorConfiguration,
      AuthInitializationAppError() => localizations.errorAuthInitialization,
      AnonymousSignInAppError() => localizations.errorAnonymousSignIn,
      ProfileLoadAppError() => localizations.errorProfileLoad,
      InvalidUsernameAppError(reason: final reason) => switch (reason) {
        UsernameErrorReason.blank => localizations.errorUsernameBlank,
        UsernameErrorReason.tooShort => localizations.errorUsernameTooShort,
        UsernameErrorReason.tooLong => localizations.errorUsernameTooLong,
        UsernameErrorReason.controlCharacter =>
          localizations.errorUsernameInvalidCharacters,
      },
      InvalidAvatarAppError() => localizations.errorInvalidAvatar,
      ProfileCreationAppError() => localizations.errorProfileCreation,
      InvalidRoomCodeAppError() => localizations.errorInvalidRoomCode,
      RoomNotFoundAppError() => localizations.errorRoomNotFound,
      RoomClosedAppError() => localizations.errorRoomClosed,
      RoomFullAppError() => localizations.errorRoomFull,
      AlreadyInAnotherRoomAppError() => localizations.errorAlreadyInRoom,
      UnsupportedGameTypeAppError() => localizations.errorUnsupportedGameType,
      InvalidMaxPlayersAppError() => localizations.errorInvalidMaxPlayers,
      ProfileRequiredAppError() => localizations.errorProfileRequired,
      NotRoomMemberAppError() => localizations.errorNotRoomMember,
      RoomOperationAppError() => localizations.errorRoomOperation,
    };
  }
}
