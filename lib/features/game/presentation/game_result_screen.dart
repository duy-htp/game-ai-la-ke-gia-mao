import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_extension.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../../room/application/room_controller.dart';
import '../application/game_phase_controller.dart';
import '../domain/game_snapshot.dart';

class GameResultScreen extends ConsumerWidget {
  const GameResultScreen({super.key});
  static const screenKey = Key('game-result-screen');
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionControllerProvider) as AppSessionReady;
    final game = session.game!;
    final result = game.result!;
    final keyword = result.localizedKeyword(
      Localizations.localeOf(context).languageCode,
    );
    final host = session.room?.hostId == session.profile.id;
    final busy = ref.watch(gamePhaseControllerProvider) is GamePhaseSubmitting;
    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(context.l10n.gameResultTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            result.winnerTeam == WinnerTeam.normal
                ? context.l10n.normalTeamWins
                : context.l10n.impostorTeamWins,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(context.l10n.resultKeyword(keyword)),
          Text(switch (result.reason) {
            GameResultReason.normalEliminated =>
              context.l10n.resultReasonNormalEliminated,
            GameResultReason.impostorFinalGuessCorrect =>
              context.l10n.resultReasonGuessCorrect,
            GameResultReason.impostorFinalGuessWrong =>
              context.l10n.resultReasonGuessWrong,
            GameResultReason.impostorFinalGuessTimeout =>
              context.l10n.resultReasonGuessTimeout,
          }),
          for (final p in game.participants)
            ListTile(
              title: Text(p.username),
              subtitle: Text(
                p.role == 'impostor'
                    ? context.l10n.youAreImpostor
                    : context.l10n.youAreNormal,
              ),
              trailing: p.playerId == result.eliminatedPlayerId
                  ? const Icon(Icons.close)
                  : null,
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(context.l10n.xpGained(result.reward.xpGained)),
                  Text(context.l10n.coinsGained(result.reward.coinsGained)),
                  Text(
                    context.l10n.newTotals(
                      result.reward.newXp,
                      result.reward.newCoins,
                      result.reward.newLevel,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (host)
            FilledButton(
              key: const Key('play-again'),
              onPressed: busy
                  ? null
                  : () => ref
                        .read(gamePhaseControllerProvider.notifier)
                        .playAgain(),
              child: Text(context.l10n.playAgain),
            )
          else
            Text(context.l10n.waitingForHost),
          OutlinedButton(
            onPressed: () =>
                ref.read(roomControllerProvider.notifier).leaveRoom(),
            child: Text(context.l10n.leaveRoom),
          ),
        ],
      ),
    );
  }
}
