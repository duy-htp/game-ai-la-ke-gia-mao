import 'package:ai_la_ke_gia_mao/core/logging/log_redactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redacts tokens and secret fields while preserving safe context', () {
    final result = LogRedactor.redact({
      'access_token': 'access-secret',
      'refresh-token': 'refresh-secret',
      'authorization': 'Bearer secret',
      'service_role': 'service-secret',
      'keyword': 'Dưa hấu',
      'keyword_id': 42,
      'word_vi': 'Dưa hấu',
      'word_en': 'Watermelon',
      'clue_text': 'Mùa hè',
      'target_id': 'private-ballot-target',
      'room_code': 'ABC23',
    });

    expect(result['room_code'], 'ABC23');
    for (final key in [
      'access_token',
      'refresh-token',
      'authorization',
      'service_role',
      'keyword',
      'keyword_id',
      'word_vi',
      'word_en',
      'clue_text',
      'target_id',
    ]) {
      expect(result[key], '[REDACTED]');
    }
  });

  test('redacts role only when the caller marks gameplay context secret', () {
    expect(LogRedactor.redact({'role': 'button'})['role'], 'button');
    expect(
      LogRedactor.redact({
        'role': 'impostor',
      }, containsGameplaySecrets: true)['role'],
      '[REDACTED]',
    );
  });

  test('propagates gameplay sensitivity into nested maps', () {
    final result = LogRedactor.redact({
      'player': <String, Object?>{'role': 'impostor'},
    }, containsGameplaySecrets: true);

    expect(result['player'], {'role': '[REDACTED]'});
  });

  test('redacts sensitive fields in nested maps', () {
    final result = LogRedactor.redact({
      'request': <String, Object?>{'access_token': 'secret'},
    });

    expect(result['request'], {'access_token': '[REDACTED]'});
  });
}
