import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_error.dart';
import 'app_environment.dart';

class AppConfig {
  const AppConfig({
    required this.environment,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.admobAndroidAppId = '',
    this.admobIosAppId = '',
    this.admobAndroidInterstitialId = '',
    this.admobIosInterstitialId = '',
    this.admobAndroidRewardedId = '',
    this.admobIosRewardedId = '',
    this.revenueCatPublicSdkKey = '',
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
      admobAndroidAppId: const String.fromEnvironment('ADMOB_ANDROID_APP_ID'),
      admobIosAppId: const String.fromEnvironment('ADMOB_IOS_APP_ID'),
      admobAndroidInterstitialId: const String.fromEnvironment(
        'ADMOB_ANDROID_INTERSTITIAL_ID',
      ),
      admobIosInterstitialId: const String.fromEnvironment(
        'ADMOB_IOS_INTERSTITIAL_ID',
      ),
      admobAndroidRewardedId: const String.fromEnvironment(
        'ADMOB_ANDROID_REWARDED_ID',
      ),
      admobIosRewardedId: const String.fromEnvironment('ADMOB_IOS_REWARDED_ID'),
      revenueCatPublicSdkKey: const String.fromEnvironment(
        'REVENUECAT_PUBLIC_SDK_KEY',
      ),
    );
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String admobAndroidAppId;
  final String admobIosAppId;
  final String admobAndroidInterstitialId;
  final String admobIosInterstitialId;
  final String admobAndroidRewardedId;
  final String admobIosRewardedId;
  final String revenueCatPublicSdkKey;

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
