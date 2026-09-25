import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_type.dart';
import 'room_code.dart';
import 'room_snapshot.dart';
import 'lobby_settings.dart';
import 'room_realtime.dart';

abstract interface class RoomRepository {
  Future<RoomSnapshot?> loadCurrentRoom();

  Future<RoomSnapshot> createRoom({
    required GameType gameType,
    required int maxPlayers,
    required String requestId,
  });

  Future<RoomSnapshot> joinRoom(RoomCode code);

  Future<void> leaveRoom();

  Future<RoomSnapshot> setReady(bool isReady);

  Future<RoomSnapshot> updateSettings(LobbySettings settings);

  Future<List<GameCategory>> loadCategories();

  Future<RoomRealtimeSession> connectRealtime(String roomId);
}

final roomRepositoryProvider = Provider<RoomRepository?>((ref) => null);
