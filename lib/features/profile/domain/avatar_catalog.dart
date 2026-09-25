import '../../../core/errors/app_error.dart';

class AvatarOption {
  const AvatarOption({required this.id, required this.emoji});

  final String id;
  final String emoji;
}

abstract final class AvatarCatalog {
  static const options = [
    AvatarOption(id: 'avatar_01', emoji: '🦊'),
    AvatarOption(id: 'avatar_02', emoji: '🐼'),
    AvatarOption(id: 'avatar_03', emoji: '🐯'),
    AvatarOption(id: 'avatar_04', emoji: '🐸'),
    AvatarOption(id: 'avatar_05', emoji: '🐙'),
    AvatarOption(id: 'avatar_06', emoji: '🦄'),
    AvatarOption(id: 'avatar_07', emoji: '🐲'),
    AvatarOption(id: 'avatar_08', emoji: '🦉'),
    AvatarOption(id: 'avatar_09', emoji: '🐧'),
    AvatarOption(id: 'avatar_10', emoji: '🦁'),
    AvatarOption(id: 'avatar_11', emoji: '🐨'),
    AvatarOption(id: 'avatar_12', emoji: '🐝'),
  ];

  static final ids = options.map((option) => option.id).toSet();

  static AvatarOption byId(String id) {
    return options.firstWhere(
      (option) => option.id == id,
      orElse: () => throw const InvalidAvatarAppError(),
    );
  }
}
