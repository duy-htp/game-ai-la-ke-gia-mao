import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_extension.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../domain/game_snapshot.dart';
import 'game_countdown.dart';

class DiscussionScreen extends ConsumerWidget {
  const DiscussionScreen({super.key});
  static const screenKey = Key('discussion-screen');
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game =
        (ref.watch(appSessionControllerProvider) as AppSessionReady).game!;
    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(context.l10n.discussion)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (game.phaseEndsAt != null)
            GameCountdown(
              endsAt: game.phaseEndsAt!,
              serverNow: game.serverNow,
              onElapsed: () {},
            ),
          Text(context.l10n.votingWillFollow),
          for (final turn in game.turns)
            if (turn.status != GameTurnStatus.active)
              ListTile(
                title: Text(game.participant(turn.playerId)?.username ?? ''),
                subtitle: Text(
                  turn.status == GameTurnStatus.timedOut
                      ? context.l10n.noClueSubmitted
                      : '“${turn.clueText}”',
                ),
              ),
        ],
      ),
    );
  }
}
