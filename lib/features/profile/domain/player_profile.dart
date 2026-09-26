import '../../../core/errors/app_error.dart';
import 'avatar_catalog.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.username,
    required this.avatarId,
    required this.coins,
    required this.xp,
    required this.level,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.normalWins = 0,
    this.impostorWins = 0,
    this.correctVotes = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlayerProfile.fromJson(Map<String, Object?> json) {
    try {
      final profile = PlayerProfile(
        id: json['id']! as String,
        username: json['username']! as String,
        avatarId: json['avatar_id']! as String,
        coins: json['coins']! as int,
        xp: json['xp']! as int,
        level: json['level']! as int,
        gamesPlayed: json['games_played'] as int? ?? 0,
        gamesWon: json['games_won'] as int? ?? 0,
        normalWins: json['normal_wins'] as int? ?? 0,
        impostorWins: json['impostor_wins'] as int? ?? 0,
        correctVotes: json['correct_votes'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at']! as String),
        updatedAt: DateTime.parse(json['updated_at']! as String),
      );
      if (profile.id.isEmpty ||
          profile.username.trim().isEmpty ||
          !AvatarCatalog.ids.contains(profile.avatarId) ||
          profile.coins < 0 ||
          profile.xp < 0 ||
          profile.level < 1 ||
          profile.gamesPlayed < 0 ||
          profile.gamesWon < 0 ||
          profile.gamesWon > profile.gamesPlayed ||
          profile.normalWins + profile.impostorWins != profile.gamesWon ||
          profile.correctVotes < 0 ||
          profile.correctVotes > profile.gamesPlayed) {
        throw const FormatException('Invalid profile values');
      }
      return profile;
    } catch (_) {
      throw const ProfileLoadAppError();
    }
  }

  final String id;
  final String username;
  final String avatarId;
  final int coins;
  final int xp;
  final int level;
  final int gamesPlayed;
  final int gamesWon;
  final int normalWins;
  final int impostorWins;
  final int correctVotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get xpIntoLevel => xp % 500;
  double get xpProgress => xpIntoLevel / 500;
  double get winRate => gamesPlayed == 0 ? 0 : gamesWon / gamesPlayed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerProfile &&
          id == other.id &&
          username == other.username &&
          avatarId == other.avatarId &&
          coins == other.coins &&
          xp == other.xp &&
          level == other.level &&
          gamesPlayed == other.gamesPlayed &&
          gamesWon == other.gamesWon &&
          normalWins == other.normalWins &&
          impostorWins == other.impostorWins &&
          correctVotes == other.correctVotes &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    username,
    avatarId,
    coins,
    xp,
    level,
    gamesPlayed,
    gamesWon,
    normalWins,
    impostorWins,
    correctVotes,
    createdAt,
    updatedAt,
  );
}
