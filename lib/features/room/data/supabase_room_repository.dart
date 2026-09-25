import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../domain/game_type.dart';
import '../domain/room_code.dart';
import '../domain/room_repository.dart';
import '../domain/room_snapshot.dart';
import 'room_repository_error_mapper.dart';

class SupabaseRoomRepository implements RoomRepository {
  SupabaseRoomRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<RoomSnapshot?> loadCurrentRoom() async {
    try {
      final response = await _client.rpc<Object?>('get_current_room');
      if (response == null) return null;
      return _parseSnapshot(response);
    } catch (error) {
      throw RoomRepositoryErrorMapper.map(error);
    }
  }

  @override
  Future<RoomSnapshot> createRoom({
    required GameType gameType,
    required int maxPlayers,
    required String requestId,
  }) async {
    if (maxPlayers < 3 || maxPlayers > 10) {
      throw const InvalidMaxPlayersAppError();
    }
    try {
      final response = await _client.rpc<Object?>(
        'create_room',
        params: {
          'p_game_type': gameType.value,
          'p_max_players': maxPlayers,
          'p_request_id': requestId,
        },
      );
      return _parseSnapshot(response);
    } catch (error) {
      throw RoomRepositoryErrorMapper.map(error);
    }
  }

  @override
  Future<RoomSnapshot> joinRoom(RoomCode code) async {
    try {
      final response = await _client.rpc<Object?>(
        'join_room',
        params: {'p_room_code': code.value},
      );
      return _parseSnapshot(response);
    } catch (error) {
      throw RoomRepositoryErrorMapper.map(error);
    }
  }

  @override
  Future<void> leaveRoom() async {
    try {
      await _client.rpc<Object?>('leave_room');
    } catch (error) {
      throw RoomRepositoryErrorMapper.map(error);
    }
  }

  RoomSnapshot _parseSnapshot(Object? response) {
    if (response is! Map) throw const RoomOperationAppError();
    return RoomSnapshot.fromJson(Map<String, Object?>.from(response));
  }
}
