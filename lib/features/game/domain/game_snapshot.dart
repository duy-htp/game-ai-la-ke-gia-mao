import '../../../core/errors/app_error.dart';
import '../../profile/domain/avatar_catalog.dart';
import 'game_status.dart';

class GameParticipantSummary {
  const GameParticipantSummary({
    required this.playerId,
    required this.username,
    required this.avatarId,
  });
  factory GameParticipantSummary.fromJson(Map<String, Object?> json) {
    final value = GameParticipantSummary(
      playerId: json['player_id']! as String,
      username: json['username']! as String,
      avatarId: json['avatar_id']! as String,
    );
    if (value.playerId.isEmpty ||
        value.username.isEmpty ||
        !AvatarCatalog.ids.contains(value.avatarId)) {
      throw const GameOperationAppError();
    }
    return value;
  }
  final String playerId;
  final String username;
  final String avatarId;
}

class GameSnapshot {
  const GameSnapshot({
    required this.gameId,
    required this.roomId,
    required this.roundNumber,
    required this.status,
    required this.phaseStartedAt,
    required this.phaseEndsAt,
    required this.revision,
    required this.participants,
  });
  factory GameSnapshot.fromJson(Map<String, Object?> json) {
    try {
      return GameSnapshot(
        gameId: json['game_id']! as String,
        roomId: json['room_id']! as String,
        roundNumber: json['round_number']! as int,
        status: GameStatus.parse(json['status']! as String),
        phaseStartedAt: DateTime.parse(json['phase_started_at']! as String),
        phaseEndsAt: json['phase_ends_at'] == null
            ? null
            : DateTime.parse(json['phase_ends_at']! as String),
        revision: json['revision']! as int,
        participants: (json['participants']! as List<Object?>)
            .map(
              (item) => GameParticipantSummary.fromJson(
                Map<String, Object?>.from(item! as Map),
              ),
            )
            .toList(growable: false),
      );
    } catch (error) {
      if (error is AppError) rethrow;
      throw const GameOperationAppError();
    }
  }
  final String gameId;
  final String roomId;
  final int roundNumber;
  final GameStatus status;
  final DateTime phaseStartedAt;
  final DateTime? phaseEndsAt;
  final int revision;
  final List<GameParticipantSummary> participants;
}
