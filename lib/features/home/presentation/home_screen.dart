import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../../profile/domain/avatar_catalog.dart';
import '../../profile/domain/player_profile.dart';
import '../../profile/presentation/avatar_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const screenKey = Key('home-screen');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final sessionState = ref.watch(appSessionControllerProvider);
    final profile = switch (sessionState) {
      AppSessionReady(:final profile) => profile,
      _ => null,
    };
    final l10n = context.l10n;

    return Scaffold(
      key: screenKey,
      body: Stack(
        children: [
          const _Atmosphere(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 42,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!config.isProduction) ...[
                              Center(
                                child: _EnvironmentBadge(
                                  label: switch (config.environment) {
                                    AppEnvironment.development =>
                                      l10n.developmentEnvironment,
                                    AppEnvironment.staging =>
                                      l10n.stagingEnvironment,
                                    AppEnvironment.production => '',
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (profile != null) ...[
                              _ProfileSummary(profile: profile),
                              const SizedBox(height: 30),
                            ],
                            _IdentityMark(label: l10n.identityMarkLabel),
                            const SizedBox(height: 24),
                            Text(
                              l10n.gameTitle,
                              key: const Key('game-title'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    fontSize: constraints.maxWidth < 360
                                        ? 32
                                        : 38,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.gameTagline,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 40),
                            FilledButton.icon(
                              key: const Key('create-room-button'),
                              onPressed: () =>
                                  context.go(RoutePaths.createRoom),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(l10n.createRoom),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              key: const Key('join-room-button'),
                              onPressed: () => context.go(RoutePaths.joinRoom),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.navy800,
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(
                                  color: AppColors.purple,
                                  width: 1.5,
                                ),
                              ),
                              icon: const Icon(Icons.login_rounded),
                              label: Text(l10n.joinRoom),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: _Shortcut(
                                    icon: Icons.person_outline_rounded,
                                    label: l10n.profile,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _Shortcut(
                                    icon: Icons.storefront_outlined,
                                    label: l10n.shop,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _Shortcut(
                                    icon: Icons.settings_outlined,
                                    label: l10n.settings,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final avatar = AvatarCatalog.byId(profile.avatarId);
    final l10n = context.l10n;
    return Card(
      key: const Key('profile-summary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AvatarBadge(emoji: avatar.emoji),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.username,
                    key: const Key('profile-username'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(l10n.playerLevel(profile.level)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              label: l10n.coinBalance(profile.coins),
              child: Text(
                '🪙 ${profile.coins}',
                key: const Key('profile-coins'),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvironmentBadge extends StatelessWidget {
  const _EnvironmentBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _IdentityMark extends StatelessWidget {
  const _IdentityMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: label,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [AppColors.indigo, AppColors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.3),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.visibility_off_rounded,
            size: 42,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: label,
      child: Opacity(
        opacity: 0.72,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.navy800,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.textMuted),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Atmosphere extends StatelessWidget {
  const _Atmosphere();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.75, -0.8),
              radius: 1.15,
              colors: [
                AppColors.indigo.withValues(alpha: 0.2),
                AppColors.navy950.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
