import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_message_mapper.dart';
import '../../../core/localization/localization_extension.dart';
import '../application/role_secret_controller.dart';
import '../application/game_phase_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../../auth/application/app_session_controller.dart';
import '../../room/application/room_realtime_controller.dart';
import '../domain/player_game_secret.dart';

class RoleRevealScreen extends ConsumerStatefulWidget {
  const RoleRevealScreen({super.key});
  static const screenKey = Key('role-reveal-screen');
  @override
  ConsumerState<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends ConsumerState<RoleRevealScreen>
    with WidgetsBindingObserver {
  Timer? _holdTimer;
  Timer? _hideTimer;
  Timer? _deadlineTimer;
  bool _revealed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      final session = ref.read(appSessionControllerProvider);
      if (session is AppSessionReady && session.room != null) {
        ref
            .read(roomRealtimeControllerProvider.notifier)
            .start(session.room!.roomId);
      }
      ref.read(gamePhaseControllerProvider.notifier).advanceIfDue();
      if (session is AppSessionReady && session.game?.phaseEndsAt != null) {
        final remaining = session.game!.phaseEndsAt!.difference(
          session.game!.serverNow,
        );
        _deadlineTimer = Timer(
          remaining.isNegative ? Duration.zero : remaining,
          () => ref.read(gamePhaseControllerProvider.notifier).advanceIfDue(),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _holdTimer?.cancel();
    _hideTimer?.cancel();
    _deadlineTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _hide();
    } else {
      ref.read(gamePhaseControllerProvider.notifier).refresh();
      ref.read(gamePhaseControllerProvider.notifier).advanceIfDue();
    }
  }

  void _startHold() {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 1), _reveal);
  }

  void _cancelHold() {
    _holdTimer?.cancel();
  }

  void _reveal() {
    if (!mounted) return;
    setState(() => _revealed = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), _hide);
  }

  void _hide() {
    _holdTimer?.cancel();
    _hideTimer?.cancel();
    if (mounted && _revealed) setState(() => _revealed = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roleSecretControllerProvider);
    return Scaffold(
      key: RoleRevealScreen.screenKey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: switch (state) {
                RoleSecretLoading() => const CircularProgressIndicator(),
                RoleSecretError(:final error) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ErrorMessageMapper.localize(error, context.l10n),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('secret-retry'),
                      onPressed: ref
                          .read(roleSecretControllerProvider.notifier)
                          .load,
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
                RoleSecretReady(:final secret) =>
                  _revealed
                      ? _SecretContent(
                          secret: secret,
                          onRemembered: () {
                            _hide();
                            ref
                                .read(gamePhaseControllerProvider.notifier)
                                .acknowledgeRole();
                          },
                        )
                      : Listener(
                          key: const Key('hold-to-reveal'),
                          onPointerDown: (_) => _startHold(),
                          onPointerUp: (_) => _cancelHold(),
                          onPointerCancel: (_) => _cancelHold(),
                          child: Card(
                            child: SizedBox(
                              height: 260,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.touch_app_rounded,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      context.l10n.holdToReveal,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SecretContent extends StatelessWidget {
  const _SecretContent({required this.secret, required this.onRemembered});
  final PlayerGameSecret secret;
  final VoidCallback onRemembered;
  @override
  Widget build(BuildContext context) {
    final normal = secret.role == PlayerRole.normal;
    final locale = Localizations.localeOf(context).languageCode;
    return Card(
      key: const Key('revealed-secret'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              normal ? Icons.groups_rounded : Icons.theater_comedy_rounded,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              normal ? context.l10n.youAreNormal : context.l10n.youAreImpostor,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            if (normal) ...[
              Text(context.l10n.secretKeyword),
              const SizedBox(height: 8),
              Text(
                locale == 'vi' ? secret.wordVi! : secret.wordEn!,
                key: const Key('secret-keyword'),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ] else
              Text(
                context.l10n.impostorHint,
                key: const Key('impostor-hint'),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('remembered-button'),
              onPressed: onRemembered,
              child: Text(context.l10n.remembered),
            ),
          ],
        ),
      ),
    );
  }
}
