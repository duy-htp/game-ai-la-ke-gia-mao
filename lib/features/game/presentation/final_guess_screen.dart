import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_message_mapper.dart';
import '../../../core/localization/localization_extension.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../application/game_phase_controller.dart';
import '../domain/game_snapshot.dart';
import 'game_countdown.dart';

class FinalGuessScreen extends ConsumerStatefulWidget {
  const FinalGuessScreen({super.key});
  static const screenKey = Key('final-guess-screen');
  @override
  ConsumerState<FinalGuessScreen> createState() => _FinalGuessScreenState();
}

class _FinalGuessScreenState extends ConsumerState<FinalGuessScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(
      () => ref.read(gamePhaseControllerProvider.notifier).advanceIfDue(),
    );
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

  Future<void> _confirm(FinalGuessChoice choice) async {
    final language = Localizations.localeOf(context).languageCode;
    final text = choice.localized(language);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.finalGuessConfirmTitle),
        content: Text(context.l10n.finalGuessConfirm(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirmVote),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref
          .read(gamePhaseControllerProvider.notifier)
          .submitFinalGuess(choice.choiceId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionControllerProvider) as AppSessionReady;
    final game = session.game!;
    final guess = game.finalGuess!;
    final mine = guess.guessingPlayerId == session.profile.id;
    final language = Localizations.localeOf(context).languageCode;
    final action = ref.watch(gamePhaseControllerProvider);
    return Scaffold(
      key: FinalGuessScreen.screenKey,
      appBar: AppBar(title: Text(context.l10n.finalGuessTitle)),
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
          if (!mine)
            Text(
              context.l10n.waitingForFinalGuess(
                game.participant(guess.guessingPlayerId)?.username ?? '',
              ),
            )
          else ...[
            Text(context.l10n.chooseKeyword),
            for (final choice in guess.choices)
              Card(
                child: ListTile(
                  title: Text(choice.localized(language)),
                  onTap: action is GamePhaseSubmitting
                      ? null
                      : () => _confirm(choice),
                ),
              ),
          ],
          if (action case GamePhaseFailure(:final error))
            Text(ErrorMessageMapper.localize(error, context.l10n)),
        ],
      ),
    );
  }
}
