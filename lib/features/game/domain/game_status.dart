enum GameStatus {
  roleReveal,
  clue,
  discussion,
  voting,
  voteResult,
  finalGuess,
  result;

  static GameStatus parse(String value) => switch (value) {
    'role_reveal' => GameStatus.roleReveal,
    'clue' => GameStatus.clue,
    'discussion' => GameStatus.discussion,
    'voting' => GameStatus.voting,
    'vote_result' => GameStatus.voteResult,
    'final_guess' => GameStatus.finalGuess,
    'result' => GameStatus.result,
    _ => throw const FormatException('Unsupported game status'),
  };
}
