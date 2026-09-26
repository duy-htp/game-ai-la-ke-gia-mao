import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../domain/game_history.dart';
import '../domain/profile_repository.dart';

class GameHistoryState {
  const GameHistoryState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.nextFinishedAt,
    this.nextGameId,
  });
  final List<GameHistoryItem> items;
  final bool loading;
  final AppError? error;
  final DateTime? nextFinishedAt;
  final String? nextGameId;
  bool get hasMore => nextFinishedAt != null && nextGameId != null;
}

class GameHistoryController extends Notifier<GameHistoryState> {
  @override
  GameHistoryState build() => const GameHistoryState();
  Future<void> refresh() => _load(reset: true);
  Future<void> loadMore() => _load(reset: false);
  Future<void> _load({required bool reset}) async {
    if (state.loading || (!reset && !state.hasMore)) return;
    final repository = ref.read(profileRepositoryProvider);
    if (repository == null) return;
    state = GameHistoryState(
      items: reset ? const [] : state.items,
      loading: true,
      nextFinishedAt: reset ? null : state.nextFinishedAt,
      nextGameId: reset ? null : state.nextGameId,
    );
    try {
      final page = await repository.fetchGameHistory(
        beforeFinishedAt: reset ? null : state.nextFinishedAt,
        beforeGameId: reset ? null : state.nextGameId,
      );
      final byId = <String, GameHistoryItem>{
        for (final item in reset ? const <GameHistoryItem>[] : state.items)
          item.gameId: item,
      };
      for (final item in page.items) {
        byId[item.gameId] = item;
      }
      state = GameHistoryState(
        items: byId.values.toList(),
        nextFinishedAt: page.nextFinishedAt,
        nextGameId: page.nextGameId,
      );
    } on AppError catch (error) {
      state = GameHistoryState(
        items: state.items,
        error: error,
        nextFinishedAt: state.nextFinishedAt,
        nextGameId: state.nextGameId,
      );
    }
  }
}

final gameHistoryControllerProvider =
    NotifierProvider<GameHistoryController, GameHistoryState>(
      GameHistoryController.new,
    );
