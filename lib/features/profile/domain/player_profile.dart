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
        createdAt: DateTime.parse(json['created_at']! as String),
        updatedAt: DateTime.parse(json['updated_at']! as String),
      );
      if (profile.id.isEmpty ||
          profile.username.trim().isEmpty ||
          !AvatarCatalog.ids.contains(profile.avatarId) ||
          profile.coins < 0 ||
          profile.xp < 0 ||
          profile.level < 1) {
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
  final DateTime createdAt;
  final DateTime updatedAt;
}
