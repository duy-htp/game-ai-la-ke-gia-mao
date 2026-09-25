enum GameStatus {
  roleReveal;

  static GameStatus parse(String value) => switch (value) {
    'role_reveal' => GameStatus.roleReveal,
    _ => throw const FormatException('Unsupported game status'),
  };
}
