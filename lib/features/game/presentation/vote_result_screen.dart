import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_extension.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../../room/application/room_realtime_controller.dart';
import '../application/game_phase_controller.dart';
import 'game_countdown.dart';

class VoteResultScreen extends ConsumerStatefulWidget {
  const VoteResultScreen({super.key});
  static const screenKey = Key('vote-result-screen');
  @override
  ConsumerState<VoteResultScreen> createState() => _VoteResultScreenState();
}

class _VoteResultScreenState extends ConsumerState<VoteResultScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      final session = ref.read(appSessionControllerProvider) as AppSessionReady;
      if (session.room != null) {
        ref
            .read(roomRealtimeControllerProvider.notifier)
            .start(session.room!.roomId);
      }
      ref.read(gamePhaseControllerProvider.notifier).advanceIfDue();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(gamePhaseControllerProvider.notifier).refresh();
      ref.read(gamePhaseControllerProvider.notifier).advanceIfDue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game =
        (ref.watch(appSessionControllerProvider) as AppSessionReady).game!;
    final voting = game.voting!;
    return Scaffold(
      key: VoteResultScreen.screenKey,
      appBar: AppBar(title: Text(context.l10n.voteResultTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (voting.nextRoundRequired && game.phaseEndsAt != null) ...[
            Text(
              context.l10n.voteTie,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            GameCountdown(
              endsAt: game.phaseEndsAt!,
              serverNow: game.serverNow,
              onElapsed: () =>
                  ref.read(gamePhaseControllerProvider.notifier).advanceIfDue(),
            ),
          ],
          if (voting.resolvedByRandomTieBreak)
            Text(context.l10n.randomTieBreak),
          for (final result in voting.results)
            ListTile(
              title: Text(game.participant(result.playerId)?.username ?? ''),
              trailing: Text('${result.voteCount}'),
            ),
          if (voting.eliminatedPlayerId != null)
            Text(
              context.l10n.eliminatedPlayer(
                game.participant(voting.eliminatedPlayerId!)?.username ?? '',
              ),
              key: const Key('eliminated-player'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
        ],
      ),
    );
  }
}
