import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_snapshot.dart';
import 'player_game_secret.dart';

abstract interface class GameRepository {
  Future<GameSnapshot> startGame(String requestId);
  Future<GameSnapshot?> loadCurrentGame();
  Future<PlayerGameSecret> loadMySecret();
}

final gameRepositoryProvider = Provider<GameRepository?>((ref) => null);
