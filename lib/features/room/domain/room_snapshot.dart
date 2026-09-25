import '../../../core/errors/app_error.dart';
import '../../profile/domain/avatar_catalog.dart';
import 'game_type.dart';
import 'lobby_settings.dart';
import 'room_code.dart';
import 'room_status.dart';

class RoomMember {
  const RoomMember({
    required this.playerId,
    required this.username,
    required this.avatarId,
    required this.seat,
    required this.isHost,
    this.isReady = false,
    required this.joinedAt,
  });

  factory RoomMember.fromJson(Map<String, Object?> json) {
    try {
      final member = RoomMember(
        playerId: json['player_id']! as String,
        username: json['username']! as String,
        avatarId: json['avatar_id']! as String,
        seat: json['seat']! as int,
        isHost: json['is_host']! as bool,
        isReady: (json['is_ready'] as bool?) ?? false,
        joinedAt: DateTime.parse(json['joined_at']! as String),
      );
      if (member.playerId.isEmpty ||
          member.username.isEmpty ||
          member.seat < 1 ||
          !AvatarCatalog.ids.contains(member.avatarId)) {
        throw const FormatException('Invalid room member');
      }
      return member;
    } catch (_) {
      throw const RoomOperationAppError();
    }
  }

  final String playerId;
  final String username;
  final String avatarId;
  final int seat;
  final bool isHost;
  final bool isReady;
  final DateTime joinedAt;
}

class RoomSnapshot {
  const RoomSnapshot({
    required this.roomId,
    required this.code,
    required this.gameType,
    required this.status,
    required this.maxPlayers,
    required this.hostId,
    this.revision = 1,
    this.settings = const LobbySettings.defaults(),
    this.canStart = false,
    required this.members,
  });

  factory RoomSnapshot.fromJson(Map<String, Object?> json) {
    try {
      final rawMembers = json['members']! as List<Object?>;
      final snapshot = RoomSnapshot(
        roomId: json['room_id']! as String,
        code: RoomCode.parse(json['code']! as String),
        gameType: GameType.parse(json['game_type']! as String),
        status: RoomStatus.parse(json['status']! as String),
        maxPlayers: json['max_players']! as int,
        hostId: json['host_id'] as String?,
        revision: (json['revision'] as int?) ?? 1,
        settings: switch (json['settings']) {
          final Map settings => LobbySettings(
            impostorCount: settings['impostor_count']! as int,
            categoryKey: settings['category_key'] as String?,
            clueSeconds: settings['clue_seconds']! as int,
            discussionSeconds: settings['discussion_seconds']! as int,
          ),
          _ => const LobbySettings.defaults(),
        },
        canStart: (json['can_start'] as bool?) ?? false,
        members: rawMembers
            .map(
              (member) => RoomMember.fromJson(
                Map<String, Object?>.from(member! as Map),
              ),
            )
            .toList(growable: false),
      );
      if (snapshot.roomId.isEmpty ||
          snapshot.maxPlayers < 3 ||
          snapshot.maxPlayers > 10 ||
          snapshot.members.length > snapshot.maxPlayers ||
          (snapshot.status == RoomStatus.waiting && snapshot.hostId == null)) {
        throw const FormatException('Invalid room snapshot');
      }
      return snapshot;
    } catch (error) {
      if (error is AppError) rethrow;
      throw const RoomOperationAppError();
    }
  }

  final String roomId;
  final RoomCode code;
  final GameType gameType;
  final RoomStatus status;
  final int maxPlayers;
  final String? hostId;
  final int revision;
  final LobbySettings settings;
  final bool canStart;
  final List<RoomMember> members;
}
