import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_message_mapper.dart';
import '../../../core/localization/localization_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../../profile/domain/avatar_catalog.dart';
import '../../profile/presentation/avatar_badge.dart';
import '../application/room_action_state.dart';
import '../application/room_controller.dart';
import '../domain/room_snapshot.dart';

class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key});

  static const screenKey = Key('room-screen');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionControllerProvider);
    final room = switch (session) {
      AppSessionReady(room: final room?) => room,
      _ => null,
    };
    if (room == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final actionState = ref.watch(roomControllerProvider);
    final leaving =
        actionState is RoomActionSubmitting &&
        actionState.action == RoomAction.leave;

    return Scaffold(
      key: RoomScreen.screenKey,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.waitingRoom,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    label: l10n.roomCodeValue(room.code.value),
                    child: Text(
                      room.code.value,
                      key: const Key('room-code'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(color: AppColors.gold, letterSpacing: 7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.gameTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.players,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(l10n.capacity(room.members.length, room.maxPlayers)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...room.members.map((member) => _MemberCard(member: member)),
                  if (actionState case RoomActionError(:final error)) ...[
                    const SizedBox(height: 16),
                    Text(
                      ErrorMessageMapper.localize(error, l10n),
                      key: const Key('room-action-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    key: const Key('leave-room-button'),
                    onPressed: leaving
                        ? null
                        : () => ref
                              .read(roomControllerProvider.notifier)
                              .leaveRoom(),
                    icon: leaving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(l10n.leaveRoom),
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

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final RoomMember member;

  @override
  Widget build(BuildContext context) {
    final avatar = AvatarCatalog.byId(member.avatarId);
    return Card(
      key: Key('room-member-${member.playerId}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${member.seat}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            AvatarBadge(emoji: avatar.emoji, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                member.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (member.isHost)
              Chip(
                avatar: const Icon(Icons.star_rounded, size: 17),
                label: Text(context.l10n.host),
              ),
          ],
        ),
      ),
    );
  }
}
