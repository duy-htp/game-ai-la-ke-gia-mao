import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_error.dart';
import 'app_environment.dart';

class AppConfig {
  const AppConfig({
    required this.environment,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
  });

  factory AppConfig.fromEnvironment({
    String? value,
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) {
    const definedValue = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const definedSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const definedSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return AppConfig(
      environment: AppEnvironment.parse(value ?? definedValue),
      supabaseUrl: (supabaseUrl ?? definedSupabaseUrl).trim(),
      supabaseAnonKey: (supabaseAnonKey ?? definedSupabaseAnonKey).trim(),
    );
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isProduction => environment == AppEnvironment.production;

  bool get hasSupabaseConfiguration =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  ({String url, String anonKey}) requireSupabaseConfiguration() {
    if (!hasSupabaseConfiguration) {
      throw const MissingConfigurationAppError();
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const InvalidConfigurationAppError();
    }
    return (url: supabaseUrl, anonKey: supabaseAnonKey);
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('AppConfig must be provided during bootstrap.'),
);
