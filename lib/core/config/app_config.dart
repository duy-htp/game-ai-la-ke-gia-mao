import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_environment.dart';

class AppConfig {
  const AppConfig({required this.environment});

  factory AppConfig.fromEnvironment({String? value}) {
    const definedValue = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    return AppConfig(environment: AppEnvironment.parse(value ?? definedValue));
  }

  final AppEnvironment environment;

  bool get isProduction => environment == AppEnvironment.production;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('AppConfig must be provided during bootstrap.'),
);
