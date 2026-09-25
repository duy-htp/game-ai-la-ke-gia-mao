import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_error.dart';
import '../core/logging/app_logger.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/profile/data/supabase_profile_repository.dart';
import '../features/profile/domain/profile_repository.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final logger = ConsoleAppLogger(environment: config.environment);
  AuthRepository? authRepository;
  ProfileRepository? profileRepository;

  try {
    final supabaseConfig = config.requireSupabaseConfiguration();
    await Supabase.initialize(
      url: supabaseConfig.url,
      publishableKey: supabaseConfig.anonKey,
    );
    final client = Supabase.instance.client;
    authRepository = SupabaseAuthRepository(
      SupabaseAuthRemoteDataSource(client),
    );
    profileRepository = SupabaseProfileRepository(client);
    logger.info('Application services initialized');
  } on AppError catch (error) {
    logger.error(
      'Application configuration is invalid',
      fields: {'error_code': error.code},
    );
  } catch (_) {
    logger.error('Supabase initialization failed');
  }

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appLoggerProvider.overrideWithValue(logger),
        if (authRepository != null)
          authRepositoryProvider.overrideWithValue(authRepository),
        if (profileRepository != null)
          profileRepositoryProvider.overrideWithValue(profileRepository),
      ],
      child: const App(),
    ),
  );
}
