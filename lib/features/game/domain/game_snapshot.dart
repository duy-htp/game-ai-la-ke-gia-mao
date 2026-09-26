import '../../../core/errors/app_error.dart';
import '../../profile/domain/avatar_catalog.dart';
import 'game_status.dart';

class GameParticipantSummary {
  const GameParticipantSummary({
    required this.playerId,
    required this.username,
    required this.avatarId,
    required this.roleAcknowledged,
    required this.discussionReady,
  });
  factory GameParticipantSummary.fromJson(Map<String, Object?> json) {
    final value = GameParticipantSummary(
      playerId: json['player_id']! as String,
      username: json['username']! as String,
      avatarId: json['avatar_id']! as String,
      roleAcknowledged: json['role_acknowledged'] as bool? ?? false,
      discussionReady: json['discussion_ready'] as bool? ?? false,
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
  final bool roleAcknowledged;
  final bool discussionReady;
}

class VoteResultEntry {
  const VoteResultEntry({required this.playerId, required this.voteCount});
  factory VoteResultEntry.fromJson(Map<String, Object?> json) =>
      VoteResultEntry(
        playerId: json['player_id']! as String,
        voteCount: json['vote_count']! as int,
      );
  final String playerId;
  final int voteCount;
}

class VotingSnapshot {
  const VotingSnapshot({
    required this.roundNumber,
    required this.endsAt,
    required this.candidates,
    required this.submittedVoteCount,
    required this.eligibleVoterCount,
    required this.currentUserHasVoted,
    required this.results,
    required this.nextRoundRequired,
    required this.eliminatedPlayerId,
    required this.resolvedByRandomTieBreak,
  });
  factory VotingSnapshot.fromJson(Map<String, Object?> json) => VotingSnapshot(
    roundNumber: json['round_number']! as int,
    endsAt: DateTime.parse(json['ends_at']! as String),
    candidates: (json['candidates']! as List<Object?>)
        .map(
          (item) => GameParticipantSummary.fromJson(
            Map<String, Object?>.from(item! as Map),
          ),
        )
        .toList(growable: false),
    submittedVoteCount: json['submitted_vote_count']! as int,
    eligibleVoterCount: json['eligible_voter_count']! as int,
    currentUserHasVoted: json['current_user_has_voted']! as bool,
    results: (json['results'] as List<Object?>? ?? const [])
        .map(
          (item) =>
              VoteResultEntry.fromJson(Map<String, Object?>.from(item! as Map)),
        )
        .toList(growable: false),
    nextRoundRequired: json['next_round_required'] as bool? ?? false,
    eliminatedPlayerId: json['eliminated_player_id'] as String?,
    resolvedByRandomTieBreak:
        json['resolved_by_random_tie_break'] as bool? ?? false,
  );
  final int roundNumber;
  final DateTime endsAt;
  final List<GameParticipantSummary> candidates;
  final int submittedVoteCount;
  final int eligibleVoterCount;
  final bool currentUserHasVoted;
  final List<VoteResultEntry> results;
  final bool nextRoundRequired;
  final String? eliminatedPlayerId;
  final bool resolvedByRandomTieBreak;
}

enum GameTurnStatus {
  active,
  submitted,
  timedOut;

  static GameTurnStatus parse(String value) => switch (value) {
    'active' => active,
    'submitted' => submitted,
    'timed_out' => timedOut,
    _ => throw const FormatException('Unsupported turn status'),
  };
}

class GameTurnSnapshot {
  const GameTurnSnapshot({
    required this.turnId,
    required this.turnIndex,
    required this.playerId,
    required this.status,
    required this.startedAt,
    required this.endsAt,
    required this.completedAt,
    required this.clueText,
  });
  factory GameTurnSnapshot.fromJson(Map<String, Object?> json) =>
      GameTurnSnapshot(
        turnId: json['turn_id']! as int,
        turnIndex: json['turn_index']! as int,
        playerId: json['player_id']! as String,
        status: GameTurnStatus.parse(json['status']! as String),
        startedAt: DateTime.parse(json['started_at']! as String),
        endsAt: DateTime.parse(json['ends_at']! as String),
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at']! as String),
        clueText: json['clue_text'] as String?,
      );
  final int turnId;
  final int turnIndex;
  final String playerId;
  final GameTurnStatus status;
  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime? completedAt;
  final String? clueText;
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
    required this.serverNow,
    required this.turns,
    this.voting,
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
        serverNow: DateTime.parse(
          (json['server_now'] ?? json['phase_started_at'])! as String,
        ),
        participants: (json['participants']! as List<Object?>)
            .map(
              (item) => GameParticipantSummary.fromJson(
                Map<String, Object?>.from(item! as Map),
              ),
            )
            .toList(growable: false),
        turns: (json['turns'] as List<Object?>? ?? const [])
            .map(
              (item) => GameTurnSnapshot.fromJson(
                Map<String, Object?>.from(item! as Map),
              ),
            )
            .toList(growable: false),
        voting: json['voting'] == null
            ? null
            : VotingSnapshot.fromJson(
                Map<String, Object?>.from(json['voting']! as Map),
              ),
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
  final DateTime serverNow;
  final List<GameTurnSnapshot> turns;
  final VotingSnapshot? voting;

  GameTurnSnapshot? get activeTurn {
    for (final turn in turns) {
      if (turn.status == GameTurnStatus.active) return turn;
    }
    return null;
  }

  GameParticipantSummary? participant(String id) {
    for (final player in participants) {
      if (player.playerId == id) return player;
    }
    return null;
  }
}
