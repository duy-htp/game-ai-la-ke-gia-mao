import '../../../core/errors/app_error.dart';

enum PlayerRole { normal, impostor }

class PlayerGameSecret {
  const PlayerGameSecret({required this.role, this.wordVi, this.wordEn});
  factory PlayerGameSecret.fromJson(Map<String, Object?> json) {
    try {
      final role = switch (json['role']) {
        'normal' => PlayerRole.normal,
        'impostor' => PlayerRole.impostor,
        _ => throw const FormatException(),
      };
      final value = PlayerGameSecret(
        role: role,
        wordVi: json['word_vi'] as String?,
        wordEn: json['word_en'] as String?,
      );
      if ((role == PlayerRole.normal &&
              (value.wordVi == null || value.wordEn == null)) ||
          (role == PlayerRole.impostor &&
              (value.wordVi != null || value.wordEn != null))) {
        throw const FormatException();
      }
      return value;
    } catch (_) {
      throw const SecretUnavailableAppError();
    }
  }
  final PlayerRole role;
  final String? wordVi;
  final String? wordEn;
}
