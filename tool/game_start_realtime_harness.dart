import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError(
      'Usage: dart run tool/game_start_realtime_harness.dart URL KEY',
    );
  }
  final clients = List.generate(3, (_) => SupabaseClient(args[0], args[1]));
  final channels = <RealtimeChannel>[];
  try {
    for (var i = 0; i < 3; i++) {
      await clients[i].auth.signInAnonymously();
      await clients[i].rpc<Object?>(
        'complete_profile',
        params: {
          'p_username': 'Game Client ${i + 1}',
          'p_avatar_id': 'avatar_0${i + 1}',
        },
      );
    }
    final room = Map<String, dynamic>.from(
      await clients[0].rpc<Object?>(
        'create_room',
        params: {
          'p_game_type': 'impostor',
          'p_max_players': 6,
          'p_request_id': const Uuid().v4(),
        },
      ) as Map,
    );
    for (var i = 1; i < 3; i++) {
      await clients[i].rpc<Object?>(
        'join_room',
        params: {'p_room_code': room['code']},
      );
      await clients[i].rpc<Object?>('set_ready', params: {'p_is_ready': true});
    }
    final invalidations = [
      Completer<Map<String, dynamic>>(),
      Completer<Map<String, dynamic>>(),
    ];
    final broadcastPayloads = <Map<String, dynamic>>[];
    for (var i = 1; i < 3; i++) {
      final id = clients[i].auth.currentUser!.id;
      final channel = clients[i].channel(
        'room:${room['room_id']}',
        opts: RealtimeChannelConfig(private: true, enabled: true, key: id),
      );
      channel.onBroadcast(
        event: 'room_changed',
        callback: (payload) {
          broadcastPayloads.add(payload);
          if (!invalidations[i - 1].isCompleted) {
            invalidations[i - 1].complete(payload);
          }
        },
      );
      await _subscribe(channel);
      await channel.track({'user_id': id});
      channels.add(channel);
    }
    final started = Map<String, dynamic>.from(
      await clients[0].rpc<Object?>(
        'start_game',
        params: {'p_request_id': const Uuid().v4()},
      ) as Map,
    );
    final payloads = await Future.wait(
      invalidations.map(
        (item) => item.future.timeout(const Duration(seconds: 8)),
      ),
    );
    for (final payload in payloads) {
      final encoded = payload.toString();
      _expect(
        !encoded.contains('keyword') &&
            !encoded.contains('role') &&
            !encoded.contains('game_players'),
        'broadcast secrecy',
      );
    }
    final snapshots = <Map<String, dynamic>>[];
    final secrets = <Map<String, dynamic>>[];
    for (final client in clients) {
      final currentRoom = Map<String, dynamic>.from(
        await client.rpc<Object?>('get_current_room') as Map,
      );
      _expect(currentRoom['status'] == 'in_game', 'room in_game convergence');
      final game = Map<String, dynamic>.from(
        await client.rpc<Object?>('get_current_game') as Map,
      );
      _expect(
        game['game_id'] == started['game_id'] &&
            game['status'] == 'role_reveal',
        'shared role reveal snapshot',
      );
      _expect(
        !game.containsKey('keyword_id') && !game.containsKey('role'),
        'public snapshot secrecy',
      );
      snapshots.add(game);
      secrets.add(
        Map<String, dynamic>.from(
          await client.rpc<Object?>('get_my_game_secret') as Map,
        ),
      );
    }
    _expect(
      secrets.where((s) => s['role'] == 'impostor').length == 1,
      'exact impostor count',
    );
    _expect(
      secrets
          .where((s) => s['role'] == 'impostor')
          .every((s) => s['word_vi'] == null && s['word_en'] == null),
      'impostor has no keyword',
    );
    _expect(
      secrets
          .where((s) => s['role'] == 'normal')
          .every((s) => s['word_vi'] != null && s['word_en'] != null),
      'normal has keyword',
    );
    for (final client in clients) {
      await client.rpc<Object?>('acknowledge_role');
    }
    var clueGame = Map<String, dynamic>.from(
      await clients[0].rpc<Object?>('get_current_game') as Map,
    );
    _expect(clueGame['status'] == 'clue', 'acknowledgements enter clue');
    _expect((clueGame['turns'] as List).length == 1, 'one first turn');
    int clientForPlayer(String playerId) =>
        clients.indexWhere((client) => client.auth.currentUser!.id == playerId);
    var active = Map<String, dynamic>.from(
      (clueGame['turns'] as List).last as Map,
    );
    await clients[clientForPlayer(active['player_id'] as String)].rpc<Object?>(
      'submit_clue',
      params: {'p_text': 'Mùa hè'},
    );
    clueGame = Map<String, dynamic>.from(
      await clients[0].rpc<Object?>('get_current_game') as Map,
    );
    _expect((clueGame['turns'] as List).length == 2, 'first clue advances');
    active = Map<String, dynamic>.from((clueGame['turns'] as List).last as Map);
    final disconnectedIndex = clientForPlayer(active['player_id'] as String);
    await clients[disconnectedIndex].removeAllChannels();
    final serverNow = DateTime.parse(clueGame['server_now'] as String);
    final turnEndsAt = DateTime.parse(active['ends_at'] as String);
    await Future<void>.delayed(
      turnEndsAt.difference(serverNow) + const Duration(seconds: 1),
    );
    await clients[(disconnectedIndex + 1) % clients.length].rpc<Object?>(
      'advance_game_if_due',
    );
    final restoredRoom = Map<String, dynamic>.from(
      await clients[disconnectedIndex].rpc<Object?>('get_current_room') as Map,
    );
    final restoredGame = Map<String, dynamic>.from(
      await clients[disconnectedIndex].rpc<Object?>('get_current_game') as Map,
    );
    final restoredSecret = Map<String, dynamic>.from(
      await clients[disconnectedIndex].rpc<Object?>('get_my_game_secret')
          as Map,
    );
    _expect(
      restoredRoom['status'] == 'in_game' &&
          restoredGame['game_id'] == started['game_id'] &&
          restoredSecret['role'] != null &&
          (restoredGame['turns'] as List).length == 3 &&
          (restoredGame['turns'] as List)[1]['status'] == 'timed_out',
      'active-turn reconnect restoration',
    );
    active = Map<String, dynamic>.from(
      (restoredGame['turns'] as List).last as Map,
    );
    await clients[clientForPlayer(active['player_id'] as String)].rpc<Object?>(
      'submit_clue',
      params: {'p_text': 'Giải khát'},
    );
    final discussion = Map<String, dynamic>.from(
      await clients[0].rpc<Object?>('get_current_game') as Map,
    );
    _expect(
      discussion['status'] == 'discussion',
      'final clue enters discussion',
    );
    _expect((discussion['turns'] as List).length == 3, 'shared turn history');
    for (final payload in broadcastPayloads) {
      final encoded = payload.toString();
      _expect(
        !encoded.contains('role') && !encoded.contains('keyword'),
        'all broadcasts remain secret-free',
      );
    }
    // ignore: avoid_print
    print(
      'PASS: 3-client role ack, clue submit, timeout, discussion and reconnect converged',
    );
  } finally {
    for (final client in clients) {
      await client.removeAllChannels();
      await client.dispose();
    }
  }
}

Future<void> _subscribe(RealtimeChannel channel) {
  final done = Completer<void>();
  channel.subscribe((status, error) {
    if (status == RealtimeSubscribeStatus.subscribed && !done.isCompleted) {
      done.complete();
    }
    if ((status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) &&
        !done.isCompleted) {
      done.completeError(StateError('$error'));
    }
  });
  return done.future.timeout(const Duration(seconds: 8));
}

void _expect(bool condition, String label) {
  if (!condition) throw StateError('Failed: $label');
}
