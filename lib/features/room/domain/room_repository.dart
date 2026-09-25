import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_type.dart';
import 'room_code.dart';
import 'room_snapshot.dart';

abstract interface class RoomRepository {
  Future<RoomSnapshot?> loadCurrentRoom();

  Future<RoomSnapshot> createRoom({
    required GameType gameType,
    required int maxPlayers,
    required String requestId,
  });

  Future<RoomSnapshot> joinRoom(RoomCode code);

  Future<void> leaveRoom();
}

final roomRepositoryProvider = Provider<RoomRepository?>((ref) => null);
