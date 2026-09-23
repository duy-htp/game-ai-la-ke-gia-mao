import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import 'log_redactor.dart';

abstract interface class AppLogger {
  void debug(
    String message, {
    Map<String, Object?> fields,
    bool containsGameplaySecrets,
  });

  void info(
    String message, {
    Map<String, Object?> fields,
    bool containsGameplaySecrets,
  });

  void warning(
    String message, {
    Map<String, Object?> fields,
    bool containsGameplaySecrets,
  });

  void error(
    String message, {
    Map<String, Object?> fields,
    bool containsGameplaySecrets,
  });
}

class ConsoleAppLogger implements AppLogger {
  const ConsoleAppLogger({required this.environment});

  final AppEnvironment environment;

  @override
  void debug(
    String message, {
    Map<String, Object?> fields = const {},
    bool containsGameplaySecrets = false,
  }) {
    if (environment != AppEnvironment.production) {
      _write('DEBUG', message, fields, containsGameplaySecrets);
    }
  }

  @override
  void info(
    String message, {
    Map<String, Object?> fields = const {},
    bool containsGameplaySecrets = false,
  }) {
    if (environment != AppEnvironment.production) {
      _write('INFO', message, fields, containsGameplaySecrets);
    }
  }

  @override
  void warning(
    String message, {
    Map<String, Object?> fields = const {},
    bool containsGameplaySecrets = false,
  }) {
    _write('WARNING', message, fields, containsGameplaySecrets);
  }

  @override
  void error(
    String message, {
    Map<String, Object?> fields = const {},
    bool containsGameplaySecrets = false,
  }) {
    _write('ERROR', message, fields, containsGameplaySecrets);
  }

  void _write(
    String level,
    String message,
    Map<String, Object?> fields,
    bool containsGameplaySecrets,
  ) {
    final safeFields = LogRedactor.redact(
      fields,
      containsGameplaySecrets: containsGameplaySecrets,
    );
    debugPrint('[$level] $message${safeFields.isEmpty ? '' : ' $safeFields'}');
  }
}

final appLoggerProvider = Provider<AppLogger>(
  (ref) => throw StateError('AppLogger must be provided during bootstrap.'),
);
