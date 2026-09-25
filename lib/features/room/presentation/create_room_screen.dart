import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_message_mapper.dart';
import '../../../core/localization/localization_extension.dart';
import '../application/room_action_state.dart';
import '../application/room_controller.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  static const screenKey = Key('create-room-screen');

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  int _maxPlayers = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actionState = ref.watch(roomControllerProvider);
    final submitting = actionState is RoomActionSubmitting;

    return Scaffold(
      key: CreateRoomScreen.screenKey,
      appBar: AppBar(title: Text(l10n.createRoom)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.gameType,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        l10n.gameTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.maximumPlayers,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '$_maxPlayers',
                        key: const Key('max-players-value'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  Slider(
                    key: const Key('max-players-slider'),
                    value: _maxPlayers.toDouble(),
                    min: 3,
                    max: 10,
                    divisions: 7,
                    label: '$_maxPlayers',
                    onChanged: submitting
                        ? null
                        : (value) =>
                              setState(() => _maxPlayers = value.round()),
                  ),
                  if (actionState case RoomActionError(:final error)) ...[
                    const SizedBox(height: 12),
                    Text(
                      ErrorMessageMapper.localize(error, l10n),
                      key: const Key('room-action-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  FilledButton(
                    key: const Key('create-room-submit'),
                    onPressed: submitting
                        ? null
                        : () => ref
                              .read(roomControllerProvider.notifier)
                              .createRoom(maxPlayers: _maxPlayers),
                    child: submitting
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(l10n.create),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: submitting ? null : context.pop,
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
