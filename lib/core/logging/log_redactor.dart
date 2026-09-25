abstract final class LogRedactor {
  static const _redacted = '[REDACTED]';
  static const _alwaysSensitiveKeys = {
    'access_token',
    'refreshtoken',
    'refresh_token',
    'authorization',
    'service_role',
    'keyword',
    'keyword_id',
    'word_vi',
    'word_en',
    'clue',
    'clue_text',
  };

  static Map<String, Object?> redact(
    Map<String, Object?> fields, {
    bool containsGameplaySecrets = false,
  }) {
    return fields.map((key, value) {
      final normalizedKey = key.toLowerCase().replaceAll('-', '_');
      final isSensitive =
          _alwaysSensitiveKeys.contains(normalizedKey) ||
          normalizedKey.contains('token') ||
          (containsGameplaySecrets && normalizedKey == 'role');
      return MapEntry(
        key,
        isSensitive
            ? _redacted
            : _redactNested(
                value,
                containsGameplaySecrets: containsGameplaySecrets,
              ),
      );
    });
  }

  static Object? _redactNested(
    Object? value, {
    required bool containsGameplaySecrets,
  }) {
    if (value is Map<String, Object?>) {
      return redact(value, containsGameplaySecrets: containsGameplaySecrets);
    }
    if (value is Iterable<Object?>) {
      return value
          .map(
            (item) => _redactNested(
              item,
              containsGameplaySecrets: containsGameplaySecrets,
            ),
          )
          .toList(growable: false);
    }
    return value;
  }
}
