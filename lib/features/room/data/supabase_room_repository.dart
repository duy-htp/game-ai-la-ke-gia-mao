import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../domain/game_type.dart';
import '../domain/room_code.dart';
import '../domain/room_repository.dart';
import '../domain/room_snapshot.dart';
import '../domain/lobby_settings.dart';
import '../domain/room_realtime.dart';
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

  @override
  Future<RoomSnapshot> setReady(bool isReady) async {
    try {
      return _parseSnapshot(
        await _client.rpc<Object?>(
          'set_ready',
          params: {'p_is_ready': isReady},
        ),
      );
    } catch (error) {
      throw RoomRepositoryErrorMapper.map(error);
    }
  }

  @override
  Future<RoomSnapshot> updateSettings(LobbySettings settings) async {
    try {
      return _parseSnapshot(
        await _client.rpc<Object?>(
          'update_room_settings',
          params: {
            'p_impostor_count': settings.impostorCount,
            'p_category_key': settings.categoryKey ?? 'random',
            'p_clue_seconds': settings.clueSeconds,
            'p_discussion_seconds': settings.discussionSeconds,
          },
        ),
      );
    } catch (error) {
      throw RoomRepositoryErrorMapper.map(error);
    }
  }

  @override
  Future<List<GameCategory>> loadCategories() async {
    try {
      final rows = await _client
          .from('categories')
          .select('key,name_vi,name_en,is_premium')
          .order('sort_order');
      return rows
          .map((row) => GameCategory.fromJson(Map<String, Object?>.from(row)))
          .toList(growable: false);
    } catch (error) {
      throw RoomRepositoryErrorMapper.map(error);
    }
  }

  @override
  Future<RoomRealtimeSession> connectRealtime(String roomId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const RoomOperationAppError();
    final session = _SupabaseRoomRealtimeSession(_client, roomId, userId);
    session.connect();
    return session;
  }

  RoomSnapshot _parseSnapshot(Object? response) {
    if (response is! Map) throw const RoomOperationAppError();
    return RoomSnapshot.fromJson(Map<String, Object?>.from(response));
  }
}

class _SupabaseRoomRealtimeSession implements RoomRealtimeSession {
  _SupabaseRoomRealtimeSession(this._client, this._roomId, this._userId);

  final SupabaseClient _client;
  final String _roomId;
  final String _userId;
  final _events = StreamController<RoomRealtimeEvent>.broadcast();
  late final RealtimeChannel _channel;

  @override
  Stream<RoomRealtimeEvent> get events => _events.stream;

  void connect() {
    _events.add(const RoomConnectionChanged(RoomConnectionState.connecting));
    _channel = _client.channel(
      'room:$_roomId',
      opts: RealtimeChannelConfig(private: true, enabled: true, key: _userId),
    );
    _channel
        .onBroadcast(
          event: 'room_changed',
          callback: (_) => _events.add(const RoomInvalidated()),
        )
        .onPresenceSync((_) => _emitPresence())
        .onPresenceJoin((_) => _emitPresence())
        .onPresenceLeave((_) => _emitPresence())
        .subscribe((status, _) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _events.add(
              const RoomConnectionChanged(RoomConnectionState.connected),
            );
            await _channel.track({'user_id': _userId});
          } else if (status != RealtimeSubscribeStatus.closed) {
            _events.add(
              const RoomConnectionChanged(RoomConnectionState.reconnecting),
            );
          }
        });
  }

  void _emitPresence() {
    _events.add(
      RoomPresenceChanged(
        _channel.presenceState().map((entry) => entry.key).toSet(),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _channel.untrack();
    await _client.removeChannel(_channel);
    await _events.close();
  }
}
