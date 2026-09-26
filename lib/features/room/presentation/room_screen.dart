import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../../profile/domain/avatar_catalog.dart';
import '../../profile/presentation/avatar_badge.dart';
import '../application/room_action_state.dart';
import '../application/room_controller.dart';
import '../application/room_realtime_controller.dart';
import '../domain/lobby_settings.dart';
import '../domain/room_realtime.dart';
import '../domain/room_snapshot.dart';
import '../../game/application/game_controller.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});
  static const screenKey = Key('room-screen');
  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  LobbySettings? _draft;
  LobbySettings? _draftBase;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionControllerProvider);
    if (session is! AppSessionReady || session.room == null) {
      return const SizedBox.shrink();
    }
    final room = session.room!;
    final isHost = room.hostId == session.profile.id;
    final realtime = ref.watch(roomRealtimeControllerProvider);
    final action = ref.watch(roomControllerProvider);
    final gameAction = ref.watch(gameControllerProvider);
    final busy =
        action is RoomActionSubmitting || gameAction is GameActionSubmitting;
    // Preserve an unsaved host draft across membership/ready revisions. Only an
    // authoritative settings change replaces it.
    if (_draft == null ||
        (_draftBase != room.settings && _draft == _draftBase)) {
      _draft = room.settings;
      _draftBase = room.settings;
    }
    final unready = room.members.where((m) => !m.isHost && !m.isReady).length;
    final reason = room.members.length < 3
        ? context.l10n.minimumPlayersRequired
        : unready > 0
        ? context.l10n.waitingReadyPlayers(unready)
        : context.l10n.invalidLobbySettings;

    return Scaffold(
      key: RoomScreen.screenKey,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.waitingRoom,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      _ConnectionChip(state: realtime.connection),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    room.code.value,
                    key: const Key('room-code'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(color: AppColors.gold, letterSpacing: 7),
                  ),
                  Text(context.l10n.gameTitle, textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.players,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        context.l10n.capacity(
                          room.members.length,
                          room.maxPlayers,
                        ),
                      ),
                    ],
                  ),
                  ...room.members.map(
                    (member) => _MemberCard(
                      member: member,
                      online: realtime.onlinePlayerIds.contains(
                        member.playerId,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SettingsCard(
                    room: room,
                    draft: _draft!,
                    isHost: isHost,
                    busy: busy,
                    onChanged: (value) => setState(() => _draft = value),
                    onSave: () async {
                      await ref
                          .read(roomControllerProvider.notifier)
                          .updateSettings(_draft!);
                      if (mounted) setState(() => _draftBase = _draft);
                    },
                  ),
                  const SizedBox(height: 14),
                  if (isHost)
                    FilledButton.icon(
                      key: const Key('start-game-button'),
                      onPressed: room.canStart && !busy
                          ? ref.read(gameControllerProvider.notifier).startGame
                          : null,
                      icon: gameAction is GameActionSubmitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        room.canStart ? context.l10n.startGame : reason,
                      ),
                    )
                  else
                    FilledButton.icon(
                      key: const Key('ready-button'),
                      onPressed: busy
                          ? null
                          : () {
                              final self = room.members.firstWhere(
                                (m) => m.playerId == session.profile.id,
                              );
                              ref
                                  .read(roomControllerProvider.notifier)
                                  .setReady(!self.isReady);
                            },
                      icon: Icon(
                        room.members
                                .firstWhere(
                                  (m) => m.playerId == session.profile.id,
                                )
                                .isReady
                            ? Icons.close_rounded
                            : Icons.check_rounded,
                      ),
                      label: Text(
                        room.members
                                .firstWhere(
                                  (m) => m.playerId == session.profile.id,
                                )
                                .isReady
                            ? context.l10n.cancelReady
                            : context.l10n.ready,
                      ),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('leave-room-button'),
                    onPressed: busy
                        ? null
                        : () async {
                            await ref
                                .read(roomControllerProvider.notifier)
                                .leaveRoom();
                          },
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(context.l10n.leaveRoom),
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

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.state});
  final RoomConnectionState state;
  @override
  Widget build(BuildContext context) => Chip(
    key: const Key('connection-indicator'),
    avatar: Icon(
      state == RoomConnectionState.connected ? Icons.wifi : Icons.sync,
      size: 16,
    ),
    label: Text(
      state == RoomConnectionState.connected
          ? context.l10n.online
          : context.l10n.reconnecting,
    ),
  );
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.online});
  final RoomMember member;
  final bool online;
  @override
  Widget build(BuildContext context) => Card(
    key: Key('room-member-${member.playerId}'),
    child: ListTile(
      leading: AvatarBadge(
        emoji: AvatarCatalog.byId(member.avatarId).emoji,
        size: 44,
      ),
      title: Text(
        member.username,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        online ? context.l10n.onlineLower : context.l10n.disconnected,
      ),
      trailing: member.isHost
          ? Chip(
              avatar: const Icon(Icons.star_rounded, size: 17),
              label: Text(context.l10n.host),
            )
          : Chip(
              avatar: Icon(
                member.isReady ? Icons.check_circle : Icons.schedule,
                size: 17,
              ),
              label: Text(
                member.isReady ? context.l10n.ready : context.l10n.notReady,
              ),
            ),
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.room,
    required this.draft,
    required this.isHost,
    required this.busy,
    required this.onChanged,
    required this.onSave,
  });
  final RoomSnapshot room;
  final LobbySettings draft;
  final bool isHost, busy;
  final ValueChanged<LobbySettings> onChanged;
  final VoidCallback onSave;

  LobbySettings _copy({
    int? impostors,
    String? category,
    bool categorySet = false,
    int? clue,
    int? discussion,
  }) => LobbySettings(
    impostorCount: impostors ?? draft.impostorCount,
    categoryKey: categorySet ? category : draft.categoryKey,
    clueSeconds: clue ?? draft.clueSeconds,
    discussionSeconds: discussion ?? draft.discussionSeconds,
  );

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.lobbySettings,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text(context.l10n.impostorCount),
          Wrap(
            spacing: 8,
            children: [1, if (room.maxPlayers >= 7) 2]
                .map(
                  (v) => ChoiceChip(
                    label: Text('$v'),
                    selected: draft.impostorCount == v,
                    onSelected: isHost
                        ? (_) => onChanged(_copy(impostors: v))
                        : null,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.category),
          DropdownButtonFormField<String>(
            key: const Key('category-selector'),
            initialValue: draft.categoryKey ?? 'random',
            items: _categories
                .map(
                  (key) => DropdownMenuItem(
                    value: key ?? 'random',
                    child: Text(_categoryName(context, key)),
                  ),
                )
                .toList(),
            onChanged: isHost
                ? (value) => onChanged(
                    _copy(
                      category: value == 'random' ? null : value,
                      categorySet: true,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(context.l10n.clueTime),
          Wrap(
            spacing: 6,
            children: [15, 30, 45, 60]
                .map(
                  (v) => ChoiceChip(
                    label: Text('${v}s'),
                    selected: draft.clueSeconds == v,
                    onSelected: isHost
                        ? (_) => onChanged(_copy(clue: v))
                        : null,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(context.l10n.discussionTime),
          Wrap(
            spacing: 6,
            children: [60, 90, 120]
                .map(
                  (v) => ChoiceChip(
                    label: Text('${v}s'),
                    selected: draft.discussionSeconds == v,
                    onSelected: isHost
                        ? (_) => onChanged(_copy(discussion: v))
                        : null,
                  ),
                )
                .toList(),
          ),
          if (isHost) ...[
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('save-settings-button'),
              onPressed: !busy && draft != room.settings ? onSave : null,
              child: Text(context.l10n.saveSettings),
            ),
          ],
        ],
      ),
    ),
  );

  static const _categories = <String?>[
    null,
    'food',
    'animals',
    'places',
    'objects',
    'jobs',
    'sports',
    'entertainment',
    'vietnam',
    'friends',
    'relationships',
  ];
  String _categoryName(BuildContext context, String? key) {
    if (key == null) return context.l10n.randomCategory;
    return switch (key) {
      'food' => context.l10n.categoryFood,
      'animals' => context.l10n.categoryAnimals,
      'places' => context.l10n.categoryPlaces,
      'objects' => context.l10n.categoryObjects,
      'jobs' => context.l10n.categoryJobs,
      'sports' => context.l10n.categorySports,
      'entertainment' => context.l10n.categoryEntertainment,
      'vietnam' => context.l10n.categoryVietnam,
      'friends' => context.l10n.categoryFriends,
      'relationships' => context.l10n.categoryRelationships,
      _ => key,
    };
  }
}
