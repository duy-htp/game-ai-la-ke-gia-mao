import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_message_mapper.dart';
import '../../../core/localization/localization_extension.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../../room/application/room_realtime_controller.dart';
import '../application/game_phase_controller.dart';
import '../domain/game_snapshot.dart';
import 'game_countdown.dart';

class ClueScreen extends ConsumerStatefulWidget {
  const ClueScreen({super.key});
  static const screenKey = Key('clue-screen');
  @override
  ConsumerState<ClueScreen> createState() => _ClueScreenState();
}

class _ClueScreenState extends ConsumerState<ClueScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
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
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
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
    final turn = game.activeTurn;
    final mine = turn?.playerId == session.profile.id;
    final action = ref.watch(gamePhaseControllerProvider);
    final current = turn == null ? null : game.participant(turn.playerId);
    return Scaffold(
      key: ClueScreen.screenKey,
      appBar: AppBar(title: Text(context.l10n.clueRound)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (turn != null)
              GameCountdown(
                endsAt: turn.endsAt,
                serverNow: game.serverNow,
                onElapsed: () => ref
                    .read(gamePhaseControllerProvider.notifier)
                    .advanceIfDue(),
              ),
            const SizedBox(height: 16),
            Text(
              mine
                  ? context.l10n.yourClueTurn
                  : context.l10n.waitingForClue(current?.username ?? ''),
            ),
            if (mine) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('clue-input'),
                controller: _controller,
                maxLength: 80,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: context.l10n.clueHint),
              ),
              FilledButton(
                key: const Key('submit-clue'),
                onPressed:
                    action is GamePhaseSubmitting ||
                        _controller.text.trim().isEmpty
                    ? null
                    : () => ref
                          .read(gamePhaseControllerProvider.notifier)
                          .submitClue(_controller.text),
                child: Text(context.l10n.submitClue),
              ),
            ],
            if (action case GamePhaseFailure(:final error))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(ErrorMessageMapper.localize(error, context.l10n)),
              ),
            const SizedBox(height: 24),
            Text(
              context.l10n.submittedClues,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final item in game.turns)
              if (item.status != GameTurnStatus.active)
                ListTile(
                  title: Text(game.participant(item.playerId)?.username ?? ''),
                  subtitle: Text(
                    item.status == GameTurnStatus.timedOut
                        ? context.l10n.noClueSubmitted
                        : '“${item.clueText}”',
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
