class GameHistoryItem {
  const GameHistoryItem({
    required this.gameId,
    required this.roundNumber,
    required this.finishedAt,
    required this.winnerTeam,
    required this.resultReason,
    required this.callerRole,
    required this.didWin,
    required this.keywordVi,
    required this.keywordEn,
    required this.categoryVi,
    required this.categoryEn,
    required this.xpGained,
    required this.coinsGained,
    required this.playerCount,
  });
  factory GameHistoryItem.fromJson(Map<String, Object?> j) => GameHistoryItem(
    gameId: j['game_id']! as String,
    roundNumber: j['round_number']! as int,
    finishedAt: DateTime.parse(j['finished_at']! as String),
    winnerTeam: j['winner_team']! as String,
    resultReason: j['result_reason']! as String,
    callerRole: j['caller_role']! as String,
    didWin: j['did_win']! as bool,
    keywordVi: j['keyword_vi']! as String,
    keywordEn: j['keyword_en']! as String,
    categoryVi: j['category_vi']! as String,
    categoryEn: j['category_en']! as String,
    xpGained: j['xp_gained']! as int,
    coinsGained: j['coins_gained']! as int,
    playerCount: j['player_count']! as int,
  );
  final String gameId, winnerTeam, resultReason, callerRole;
  final String keywordVi, keywordEn, categoryVi, categoryEn;
  final int roundNumber, xpGained, coinsGained, playerCount;
  final DateTime finishedAt;
  final bool didWin;
  String keyword(String language) => language == 'vi' ? keywordVi : keywordEn;
  String category(String language) =>
      language == 'vi' ? categoryVi : categoryEn;
}

class GameHistoryPage {
  const GameHistoryPage({
    required this.items,
    this.nextFinishedAt,
    this.nextGameId,
  });
  factory GameHistoryPage.fromJson(Map<String, Object?> j) => GameHistoryPage(
    items: (j['items']! as List)
        .map(
          (e) => GameHistoryItem.fromJson(Map<String, Object?>.from(e as Map)),
        )
        .toList(growable: false),
    nextFinishedAt: j['next_finished_at'] == null
        ? null
        : DateTime.parse(j['next_finished_at']! as String),
    nextGameId: j['next_game_id'] as String?,
  );
  final List<GameHistoryItem> items;
  final DateTime? nextFinishedAt;
  final String? nextGameId;
  bool get hasMore => nextFinishedAt != null && nextGameId != null;
}
