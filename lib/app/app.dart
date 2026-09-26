import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/recovery/recovery_controller.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/application/app_session_controller.dart';
import '../features/auth/application/app_session_state.dart';
import '../features/room/application/room_realtime_controller.dart';
import '../features/room/domain/room_realtime.dart';
import '../features/monetization/application/monetization_controller.dart';
import '../l10n/app_localizations.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key, this.locale});

  final Locale? locale;

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  late final RoomRealtimeController _realtimeController;

  @override
  void initState() {
    super.initState();
    _realtimeController = ref.read(roomRealtimeControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await ref.read(appSessionControllerProvider.notifier).initialize();
      await ref.read(monetizationControllerProvider.notifier).initialize();
      await ref.read(recoveryControllerProvider.notifier).activate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_realtimeController.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref
            .read(recoveryControllerProvider.notifier)
            .recover(RecoveryReason.resumed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppSessionState>(appSessionControllerProvider, (_, next) {
      unawaited(
        ref.read(recoveryControllerProvider.notifier).syncSubscription(),
      );
    });
    final connection = ref.watch(roomRealtimeControllerProvider).connection;
    final recovery = ref.watch(recoveryControllerProvider);
    final session = ref.watch(appSessionControllerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: widget.locale ?? const Locale('vi'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context).gameTitle,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        final hasRoom = session is AppSessionReady && session.room != null;
        final disconnected =
            hasRoom && connection != RoomConnectionState.connected;
        if (!disconnected && recovery.status != RecoveryStatus.failed) {
          return child ?? const SizedBox.shrink();
        }
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Material(
                color: recovery.status == RecoveryStatus.failed
                    ? Colors.red.shade800
                    : Colors.orange.shade800,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            recovery.status == RecoveryStatus.failed
                                ? AppLocalizations.of(context).connectionLost
                                : AppLocalizations.of(context).reconnecting,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (recovery.status == RecoveryStatus.failed)
                          TextButton(
                            key: const Key('recovery-retry'),
                            onPressed: () => ref
                                .read(recoveryControllerProvider.notifier)
                                .recover(RecoveryReason.manual),
                            child: Text(AppLocalizations.of(context).retry),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
