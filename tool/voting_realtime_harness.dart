import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError(
      'Usage: dart run tool/voting_realtime_harness.dart URL KEY',
    );
  }
  await _uniqueResult(args[0], args[1]);
  await _firstTieRevote(args[0], args[1], secondTie: false);
  await _firstTieRevote(args[0], args[1], secondTie: true);
  // ignore: avoid_print
  print(
    'PASS: voting scenarios A/B/C, ballot secrecy, realtime and reconnect converged',
  );
}

Future<void> _uniqueResult(String url, String key) async {
  final h = await _Harness.create(url, key, 'A');
  try {
    await h.enterVoting();
    final game = await h.game(0);
    final voting = Map<String, dynamic>.from(game['voting'] as Map);
    _expect(voting['results'] == null, 'active totals hidden');
    await h.vote(0, 1);
    final afterOne = await h.game(2);
    final safe = Map<String, dynamic>.from(afterOne['voting'] as Map);
    _expect(
      safe['submitted_vote_count'] == 1 && safe['results'] == null,
      'only generic progress visible',
    );
    try {
      await h.clients[0].from('votes').select();
      throw StateError('direct vote select succeeded');
    } on PostgrestException catch (_) {}
    final refresh = h.clients[0].auth.currentSession!.refreshToken!;
    await h.clients[0].dispose();
    final replacement = SupabaseClient(url, key);
    await replacement.auth.setSession(refresh);
    h.clients[0] = replacement;
    final restored = await h.game(0);
    _expect(
      (restored['voting'] as Map)['current_user_has_voted'] == true,
      'reconnect restores has-voted only',
    );
    await h.vote(1, 0);
    await h.vote(2, 1);
    await h.expectAll('vote_result', eliminated: h.ids[1]);
    _expect(
      h.payloads.every(
        (p) =>
            !p.toString().contains('target') && !p.toString().contains('voter'),
      ),
      'broadcast ballot secrecy',
    );
  } finally {
    await h.dispose();
  }
}

Future<void> _firstTieRevote(
  String url,
  String key, {
  required bool secondTie,
}) async {
  final h = await _Harness.create(url, key, secondTie ? 'C' : 'B');
  try {
    await h.enterVoting();
    await h.vote(0, 1);
    await h.vote(1, 0);
    await Future<void>.delayed(const Duration(seconds: 31));
    await h.advance(2);
    var game = await h.game(0);
    _expect(
      game['status'] == 'vote_result' &&
          (game['voting'] as Map)['next_round_required'] == true,
      'first tie result',
    );
    await Future<void>.delayed(const Duration(seconds: 6));
    await h.advance(0);
    game = await h.game(1);
    final voting = Map<String, dynamic>.from(game['voting'] as Map);
    _expect(
      game['status'] == 'voting' &&
          voting['round_number'] == 2 &&
          (voting['candidates'] as List).length == 2,
      'revote tied candidates only',
    );
    await h.vote(0, 1);
    await h.vote(1, 0);
    if (secondTie) {
      await Future<void>.delayed(const Duration(seconds: 31));
      await h.advance(2);
      game = await h.game(0);
      _expect(
        game['status'] == 'vote_result' &&
            (game['voting'] as Map)['resolved_by_random_tie_break'] == true &&
            (game['voting'] as Map)['eliminated_player_id'] != null,
        'second tie random resolution',
      );
    } else {
      await h.vote(2, 0);
      await h.expectAll('vote_result', eliminated: h.ids[0]);
    }
  } finally {
    await h.dispose();
  }
}

class _Harness {
  _Harness(this.clients, this.ids, this.roomId, this.payloads);
  final List<SupabaseClient> clients;
  final List<String> ids;
  final String roomId;
  final List<Map<String, dynamic>> payloads;
  static Future<_Harness> create(String url, String key, String suffix) async {
    final clients = List.generate(3, (_) => SupabaseClient(url, key));
    for (var i = 0; i < 3; i++) {
      await clients[i].auth.signInAnonymously();
      await clients[i].rpc<Object?>(
        'complete_profile',
        params: {
          'p_username': 'Vote $suffix ${i + 1}',
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
    final payloads = <Map<String, dynamic>>[];
    for (final client in clients) {
      final channel = client.channel(
        'room:${room['room_id']}',
        opts: RealtimeChannelConfig(
          private: true,
          enabled: true,
          key: client.auth.currentUser!.id,
        ),
      );
      channel.onBroadcast(
        event: 'room_changed',
        callback: (p) => payloads.add(p),
      );
      await _subscribe(channel);
    }
    await clients[0].rpc<Object?>(
      'start_game',
      params: {'p_request_id': const Uuid().v4()},
    );
    for (final client in clients) {
      await client.rpc<Object?>('acknowledge_role');
    }
    for (var turn = 0; turn < 3; turn++) {
      final game = Map<String, dynamic>.from(
        await clients[0].rpc<Object?>('get_current_game') as Map,
      );
      final active = (game['turns'] as List).cast<Map>().lastWhere(
        (t) => t['status'] == 'active',
      );
      final index = clients.indexWhere(
        (c) => c.auth.currentUser!.id == active['player_id'],
      );
      await clients[index].rpc<Object?>(
        'submit_clue',
        params: {'p_text': 'Signal ${turn + 1}'},
      );
    }
    return _Harness(
      clients,
      clients.map((c) => c.auth.currentUser!.id).toList(),
      room['room_id'] as String,
      payloads,
    );
  }

  Future<void> enterVoting() async {
    for (final c in clients) {
      await c.rpc<Object?>('set_discussion_ready', params: {'p_ready': true});
    }
    await expectAll('voting');
  }

  Future<void> vote(int voter, int target) => clients[voter].rpc<Object?>(
    'submit_vote',
    params: {'p_target_player_id': ids[target]},
  );
  Future<void> advance(int player) =>
      clients[player].rpc<Object?>('advance_game_if_due');
  Future<Map<String, dynamic>> game(int player) async =>
      Map<String, dynamic>.from(
        await clients[player].rpc<Object?>('get_current_game') as Map,
      );
  Future<void> expectAll(String status, {String? eliminated}) async {
    for (var i = 0; i < clients.length; i++) {
      final g = await game(i);
      _expect(g['status'] == status, 'client $i status $status');
      if (eliminated != null) {
        _expect(
          (g['voting'] as Map)['eliminated_player_id'] == eliminated,
          'client $i eliminated',
        );
      }
    }
  }

  Future<void> dispose() async {
    for (final c in clients) {
      await c.removeAllChannels();
      await c.dispose();
    }
  }
}

Future<void> _subscribe(RealtimeChannel channel) {
  final done = Completer<void>();
  channel.subscribe((s, e) {
    if (s == RealtimeSubscribeStatus.subscribed && !done.isCompleted) {
      done.complete();
    }
    if ((s == RealtimeSubscribeStatus.channelError ||
            s == RealtimeSubscribeStatus.timedOut) &&
        !done.isCompleted) {
      done.completeError(StateError('$e'));
    }
  });
  return done.future.timeout(const Duration(seconds: 8));
}

void _expect(bool value, String label) {
  if (!value) throw StateError('Failed: $label');
}
