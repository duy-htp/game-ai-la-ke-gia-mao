import '../../../core/errors/app_error.dart';

enum GameType {
  impostor('impostor');

  const GameType(this.value);

  final String value;

  static GameType parse(String value) {
    return GameType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => throw const UnsupportedGameTypeAppError(),
    );
  }
}
