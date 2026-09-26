import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../core/errors/error_message_mapper.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../../monetization/application/monetization_controller.dart';
import '../../monetization/domain/ads_service.dart';
import '../../monetization/domain/purchase_service.dart';
import '../application/game_history_controller.dart';
import '../application/profile_controller.dart';
import '../domain/avatar_catalog.dart';
import 'avatar_badge.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  static const screenKey = Key('profile-screen');
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(profileControllerProvider.notifier).refresh();
      await ref.read(gameHistoryControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionControllerProvider) as AppSessionReady;
    final p = session.profile;
    final history = ref.watch(gameHistoryControllerProvider);
    final action = ref.watch(profileControllerProvider);
    final monetization = ref.watch(monetizationControllerProvider);
    return Scaffold(
      key: ProfileScreen.screenKey,
      appBar: AppBar(title: Text(context.l10n.profileTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(profileControllerProvider.notifier).refresh();
          await ref.read(gameHistoryControllerProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: AvatarBadge(
                emoji: AvatarCatalog.byId(p.avatarId).emoji,
                size: 84,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              p.username,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              context.l10n.playerLevel(p.level),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Semantics(
              label: context.l10n.xpProgress(p.xpIntoLevel, 500),
              child: LinearProgressIndicator(value: p.xpProgress),
            ),
            Text(
              context.l10n.xpProgress(p.xpIntoLevel, 500),
              textAlign: TextAlign.center,
            ),
            Text(
              context.l10n.coinBalance(p.coins),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    FilledButton.icon(
                      key: const Key('watch-rewarded-ad'),
                      onPressed:
                          monetization.authoritative?.canWatchRewardedAd == true
                          ? () => _watchRewarded(context)
                          : null,
                      icon: const Icon(Icons.smart_display_outlined),
                      label: Text(context.l10n.watchAdCoins),
                    ),
                    Text(
                      context.l10n.rewardedRemaining(
                        monetization.authoritative?.rewardedRemainingToday ?? 0,
                        3,
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.l10n.removeAds),
                              Text(
                                monetization.authoritative?.removeAds == true
                                    ? context.l10n.alreadyOwned
                                    : monetization.product?.localizedPrice ??
                                          context.l10n.storeUnavailable,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (monetization.authoritative?.removeAds == true)
                          const Icon(Icons.verified_outlined)
                        else
                          SizedBox(
                            width: 88,
                            child: FilledButton(
                              key: const Key('purchase-remove-ads'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: monetization.product == null
                                  ? null
                                  : () => _purchase(context),
                              child: Text(context.l10n.buy),
                            ),
                          ),
                      ],
                    ),
                    TextButton(
                      key: const Key('restore-purchases'),
                      onPressed: () => _restore(context),
                      child: Text(context.l10n.restorePurchases),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('edit-profile'),
              onPressed: () => _edit(context, p.username, p.avatarId),
              icon: const Icon(Icons.edit),
              label: Text(context.l10n.editProfile),
            ),
            if (action case ProfileFailure(:final error)) ...[
              const SizedBox(height: 8),
              Text(
                ErrorMessageMapper.localize(error, context.l10n),
                key: const Key('profile-error'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              context.l10n.statistics,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisExtent: 100,
              children: [
                _Stat(context.l10n.gamesPlayed, p.gamesPlayed),
                _Stat(context.l10n.gamesWon, p.gamesWon),
                _Stat(context.l10n.normalWins, p.normalWins),
                _Stat(context.l10n.impostorWins, p.impostorWins),
                _Stat(context.l10n.correctVotes, p.correctVotes),
                _Stat(context.l10n.winRateLabel, (p.winRate * 100).round()),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.recentGames,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (history.loading && history.items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (history.error != null && history.items.isEmpty)
              TextButton(
                onPressed: ref
                    .read(gameHistoryControllerProvider.notifier)
                    .refresh,
                child: Text(context.l10n.retry),
              )
            else if (history.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.noGameHistory,
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...history.items.map(
                (item) => Card(
                  child: ListTile(
                    title: Text(
                      item.didWin
                          ? context.l10n.historyWin
                          : context.l10n.historyLoss,
                    ),
                    subtitle: Text(
                      '${item.keyword(Localizations.localeOf(context).languageCode)} • ${MaterialLocalizations.of(context).formatCompactDate(item.finishedAt.toLocal())}',
                    ),
                    trailing: Text(
                      '+${item.xpGained} XP\n+${item.coinsGained} 🪙',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
              ),
            if (history.hasMore)
              TextButton(
                onPressed: history.loading
                    ? null
                    : ref.read(gameHistoryControllerProvider.notifier).loadMore,
                child: Text(context.l10n.loadMore),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _watchRewarded(BuildContext context) async {
    final outcome = await ref
        .read(monetizationControllerProvider.notifier)
        .watchRewarded();
    if (!context.mounted) return;
    final message = switch (outcome) {
      RewardedAdOutcome.completed => context.l10n.rewardVerificationPending,
      RewardedAdOutcome.closedEarly => context.l10n.adClosedEarly,
      RewardedAdOutcome.unavailable => context.l10n.adUnavailable,
      RewardedAdOutcome.failed => context.l10n.adFailed,
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _purchase(BuildContext context) async {
    final outcome = await ref
        .read(monetizationControllerProvider.notifier)
        .purchaseRemoveAds();
    if (!context.mounted) return;
    final message = switch (outcome) {
      PurchaseOutcome.submitted => context.l10n.purchaseVerificationPending,
      PurchaseOutcome.cancelled => context.l10n.purchaseCancelled,
      PurchaseOutcome.unavailable => context.l10n.storeUnavailable,
      PurchaseOutcome.failed => context.l10n.purchaseFailed,
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(BuildContext context) async {
    final outcome = await ref
        .read(monetizationControllerProvider.notifier)
        .restorePurchases();
    if (!context.mounted) return;
    final message = switch (outcome) {
      RestoreOutcome.submitted => context.l10n.restoreVerificationPending,
      RestoreOutcome.nothingToRestore => context.l10n.nothingToRestore,
      RestoreOutcome.unavailable => context.l10n.storeUnavailable,
      RestoreOutcome.failed => context.l10n.restoreFailed,
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit(
    BuildContext context,
    String username,
    String avatarId,
  ) async {
    final controller = TextEditingController(text: username);
    var selected = avatarId;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(context.l10n.editProfile),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('edit-username'),
                  controller: controller,
                  maxLength: 20,
                ),
                Wrap(
                  children: [
                    for (final avatar in AvatarCatalog.options)
                      IconButton(
                        onPressed: () => setLocal(() => selected = avatar.id),
                        icon: Text(
                          avatar.emoji,
                          style: TextStyle(
                            fontSize: selected == avatar.id ? 32 : 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('save-profile'),
              onPressed: () async {
                final ok = await ref
                    .read(profileControllerProvider.notifier)
                    .save(controller.text, selected);
                if (context.mounted && ok) Navigator.pop(context, true);
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == true && mounted) setState(() {});
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            child: Text(
              '$value',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}
