import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    for (final environment in AppEnvironment.values) {
      test('parses ${environment.value}', () {
        final config = AppConfig.fromEnvironment(value: environment.value);

        expect(config.environment, environment);
      });
    }

    test('normalizes whitespace and case', () {
      final config = AppConfig.fromEnvironment(value: ' STAGING ');

      expect(config.environment, AppEnvironment.staging);
    });

    test('rejects an unsupported environment', () {
      expect(
        () => AppConfig.fromEnvironment(value: 'preview'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
