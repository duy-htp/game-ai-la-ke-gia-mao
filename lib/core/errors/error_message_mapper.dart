import '../../l10n/app_localizations.dart';
import 'app_error.dart';

abstract final class ErrorMessageMapper {
  static String localize(AppError error, AppLocalizations localizations) {
    return switch (error) {
      NetworkAppError() => localizations.errorNetworkUnavailable,
      SessionExpiredAppError() => localizations.errorSessionExpired,
      UnexpectedAppError() => localizations.errorUnexpected,
    };
  }
}
