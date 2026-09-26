enum GameStatus {
  roleReveal,
  clue,
  discussion,
  voting,
  voteResult;

  static GameStatus parse(String value) => switch (value) {
    'role_reveal' => GameStatus.roleReveal,
    'clue' => GameStatus.clue,
    'discussion' => GameStatus.discussion,
    'voting' => GameStatus.voting,
    'vote_result' => GameStatus.voteResult,
    _ => throw const FormatException('Unsupported game status'),
  };
}
