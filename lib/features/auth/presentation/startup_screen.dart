import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_message_mapper.dart';
import '../../../core/localization/localization_extension.dart';
import '../../profile/presentation/avatar_badge.dart';
import '../application/app_session_controller.dart';
import '../application/app_session_state.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  static const screenKey = Key('startup-screen');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appSessionControllerProvider);
    final l10n = context.l10n;
    final error = switch (state) {
      AppSessionRecoverableError(:final error) => error,
      AppSessionFatalConfigurationError(:final error) => error,
      _ => null,
    };
    final canRetry = state is AppSessionRecoverableError;

    return Scaffold(
      key: screenKey,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AvatarBadge(emoji: '🕵️', size: 88),
                  const SizedBox(height: 28),
                  if (error == null) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(l10n.authInitializing, textAlign: TextAlign.center),
                  ] else ...[
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 42,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      ErrorMessageMapper.localize(error, l10n),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (canRetry) ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const Key('retry-button'),
                        onPressed: () => ref
                            .read(appSessionControllerProvider.notifier)
                            .retry(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(l10n.retry),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
