import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_extension.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../../room/application/room_realtime_controller.dart';
import '../application/game_phase_controller.dart';
import '../domain/game_snapshot.dart';
import 'game_countdown.dart';

class DiscussionScreen extends ConsumerStatefulWidget {
  const DiscussionScreen({super.key});
  static const screenKey = Key('discussion-screen');
  @override
  ConsumerState<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends ConsumerState<DiscussionScreen>
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
    final session = ref.watch(appSessionControllerProvider) as AppSessionReady;
    final game = session.game!;
    final me = game.participant(session.profile.id)!;
    final busy = ref.watch(gamePhaseControllerProvider) is GamePhaseSubmitting;
    return Scaffold(
      key: DiscussionScreen.screenKey,
      appBar: AppBar(title: Text(context.l10n.discussion)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (game.phaseEndsAt != null)
            GameCountdown(
              endsAt: game.phaseEndsAt!,
              serverNow: game.serverNow,
              onElapsed: () =>
                  ref.read(gamePhaseControllerProvider.notifier).advanceIfDue(),
            ),
          for (final participant in game.participants)
            ListTile(
              title: Text(participant.username),
              trailing: Text(
                participant.discussionReady
                    ? context.l10n.readyToVoteStatus
                    : context.l10n.discussingStatus,
              ),
            ),
          FilledButton(
            key: const Key('discussion-ready-button'),
            onPressed: busy
                ? null
                : () => ref
                      .read(gamePhaseControllerProvider.notifier)
                      .setDiscussionReady(!me.discussionReady),
            child: Text(
              me.discussionReady
                  ? context.l10n.cancelVoteReady
                  : context.l10n.readyToVote,
            ),
          ),
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
