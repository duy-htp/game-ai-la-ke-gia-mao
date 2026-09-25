class LobbySettings {
  const LobbySettings({
    required this.impostorCount,
    required this.categoryKey,
    required this.clueSeconds,
    required this.discussionSeconds,
  });

  const LobbySettings.defaults()
    : impostorCount = 1,
      categoryKey = null,
      clueSeconds = 30,
      discussionSeconds = 90;

  final int impostorCount;
  final String? categoryKey;
  final int clueSeconds;
  final int discussionSeconds;

  bool get isRandomCategory => categoryKey == null;

  @override
  bool operator ==(Object other) =>
      other is LobbySettings &&
      impostorCount == other.impostorCount &&
      categoryKey == other.categoryKey &&
      clueSeconds == other.clueSeconds &&
      discussionSeconds == other.discussionSeconds;

  @override
  int get hashCode =>
      Object.hash(impostorCount, categoryKey, clueSeconds, discussionSeconds);
}

class GameCategory {
  const GameCategory({
    required this.key,
    required this.nameVi,
    required this.nameEn,
    required this.isPremium,
  });

  factory GameCategory.fromJson(Map<String, Object?> json) => GameCategory(
    key: json['key']! as String,
    nameVi: json['name_vi']! as String,
    nameEn: json['name_en']! as String,
    isPremium: json['is_premium']! as bool,
  );

  final String key;
  final String nameVi;
  final String nameEn;
  final bool isPremium;
}
