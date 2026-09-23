import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/logging/app_logger.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final logger = ConsoleAppLogger(environment: config.environment);
  logger.info('Application bootstrap completed');

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appLoggerProvider.overrideWithValue(logger),
      ],
      child: const App(),
    ),
  );
}
