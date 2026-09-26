import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_message_mapper.dart';
import '../../../core/localization/localization_extension.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../../room/application/room_realtime_controller.dart';
import '../application/game_phase_controller.dart';
import 'game_countdown.dart';

class VotingScreen extends ConsumerStatefulWidget {
  const VotingScreen({super.key});
  static const screenKey = Key('voting-screen');
  @override
  ConsumerState<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends ConsumerState<VotingScreen>
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

  Future<void> _confirm(String id, String username) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.confirmVoteTitle),
        content: Text(context.l10n.confirmVoteFor(username)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-vote'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirmVote),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await ref.read(gamePhaseControllerProvider.notifier).submitVote(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionControllerProvider) as AppSessionReady;
    final game = session.game!;
    final voting = game.voting!;
    final action = ref.watch(gamePhaseControllerProvider);
    final locked = voting.currentUserHasVoted || action is GamePhaseSubmitting;
    return Scaffold(
      key: VotingScreen.screenKey,
      appBar: AppBar(
        title: Text(
          voting.roundNumber == 1
              ? context.l10n.votingTitle
              : context.l10n.revoteTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GameCountdown(
            endsAt: voting.endsAt,
            serverNow: game.serverNow,
            onElapsed: () =>
                ref.read(gamePhaseControllerProvider.notifier).advanceIfDue(),
          ),
          Text(
            context.l10n.votesSubmitted(
              voting.submittedVoteCount,
              voting.eligibleVoterCount,
            ),
          ),
          if (voting.currentUserHasVoted) ...[
            Text(context.l10n.voteSubmitted),
            Text(context.l10n.waitingForVotes),
          ],
          for (final candidate in voting.candidates)
            Card(
              child: ListTile(
                title: Text(candidate.username),
                leading: const CircleAvatar(child: Icon(Icons.person)),
                onTap: locked || candidate.playerId == session.profile.id
                    ? null
                    : () => _confirm(candidate.playerId, candidate.username),
              ),
            ),
          if (action case GamePhaseFailure(:final error))
            Text(ErrorMessageMapper.localize(error, context.l10n)),
        ],
      ),
    );
  }
}
