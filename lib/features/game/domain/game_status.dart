enum GameStatus {
  roleReveal,
  clue,
  discussion;

  static GameStatus parse(String value) => switch (value) {
    'role_reveal' => GameStatus.roleReveal,
    'clue' => GameStatus.clue,
    'discussion' => GameStatus.discussion,
    _ => throw const FormatException('Unsupported game status'),
  };
}
