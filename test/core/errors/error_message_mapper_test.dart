import 'dart:ui';

import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/core/errors/error_message_mapper.dart';
import 'package:ai_la_ke_gia_mao/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps typed errors to localized safe messages', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    expect(
      ErrorMessageMapper.localize(const NetworkAppError(), l10n),
      'Không có kết nối mạng. Vui lòng thử lại.',
    );
    expect(
      ErrorMessageMapper.localize(const SessionExpiredAppError(), l10n),
      isNot(contains('session_expired')),
    );
    expect(
      ErrorMessageMapper.localize(const UnexpectedAppError(), l10n),
      isNotEmpty,
    );
  });
}
