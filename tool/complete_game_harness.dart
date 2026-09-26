import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

enum _Outcome { normalEliminated, wrongGuess, correctGuess }

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError(
      'Usage: dart run tool/complete_game_harness.dart URL KEY',
    );
  }
  for (final outcome in _Outcome.values) {
    final harness = await _Harness.create(args[0], args[1], outcome.name);
    try {
      await harness.complete(outcome);
    } finally {
      await harness.dispose();
    }
  }
  // ignore: avoid_print
  print(
    'PASS: complete-game normal-eliminated/wrong/correct scenarios, security, '
    'reconnect, rewards and Play Again converged',
  );
}

class _Harness {
  _Harness(this.url, this.key, this.clients, this.roomId, this.payloads);

  final String url;
  final String key;
  final List<SupabaseClient> clients;
  final String roomId;
  final List<Map<String, dynamic>> payloads;

  List<String> get ids =>
      clients.map((client) => client.auth.currentUser!.id).toList();

  static Future<_Harness> create(String url, String key, String suffix) async {
    final clients = List.generate(3, (_) => SupabaseClient(url, key));
    for (var i = 0; i < clients.length; i++) {
      await clients[i].auth.signInAnonymously();
      await clients[i].rpc<Object?>(
        'complete_profile',
        params: {
          'p_username': 'M8 ${suffix.substring(0, 3)} ${i + 1}',
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
    for (var i = 1; i < clients.length; i++) {
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
      channel.onBroadcast(event: 'room_changed', callback: payloads.add);
      await _subscribe(channel);
    }
    return _Harness(url, key, clients, room['room_id'] as String, payloads);
  }

  Future<void> complete(_Outcome outcome) async {
    await clients[0].rpc<Object?>(
      'start_game',
      params: {'p_request_id': const Uuid().v4()},
    );
    final secrets = <Map<String, dynamic>>[];
    for (final client in clients) {
      secrets.add(
        Map<String, dynamic>.from(
          await client.rpc<Object?>('get_my_game_secret') as Map,
        ),
      );
      await client.rpc<Object?>('acknowledge_role');
    }
    final impostor = secrets.indexWhere(
      (secret) => secret['role'] == 'impostor',
    );
    _expect(impostor >= 0, 'one impostor exists');
    final normal = List.generate(
      3,
      (index) => index,
    ).firstWhere((index) => index != impostor);
    for (var turn = 0; turn < 3; turn++) {
      final snapshot = await game(0);
      final active = (snapshot['turns'] as List).cast<Map>().lastWhere(
        (value) => value['status'] == 'active',
      );
      final actor = ids.indexOf(active['player_id'] as String);
      await clients[actor].rpc<Object?>(
        'submit_clue',
        params: {'p_text': 'Signal ${turn + 1}'},
      );
    }
    for (final client in clients) {
      await client.rpc<Object?>(
        'set_discussion_ready',
        params: {'p_ready': true},
      );
    }
    final target = outcome == _Outcome.normalEliminated ? normal : impostor;
    final voters = List.generate(
      3,
      (index) => index,
    ).where((index) => index != target).toList();
    await vote(voters[0], target);
    await vote(voters[1], target);
    await vote(target, voters[0]);
    await expectStatus('vote_result');
    await Future<void>.delayed(const Duration(seconds: 6));
    await clients[0].rpc<Object?>('advance_game_if_due');

    if (outcome == _Outcome.normalEliminated) {
      await expectResult('impostor', 'normal_eliminated');
    } else {
      await expectStatus('final_guess');
      for (var i = 0; i < clients.length; i++) {
        final choices =
            ((await game(i))['final_guess'] as Map)['choices'] as List;
        _expect(
          choices.length == (i == impostor ? 4 : 0),
          'only eliminated impostor sees four choices',
        );
      }
      await _expectPostgrestFailure(
        () => clients[normal].rpc<Object?>(
          'submit_final_guess',
          params: {'p_choice_id': const Uuid().v4()},
        ),
        'normal cannot submit final guess',
      );
      await _expectPostgrestFailure(
        () => clients[normal].from('final_guess_options').select(),
        'private option table cannot be read',
      );
      await reconnect(impostor);
      final restored = await game(impostor);
      final choices = ((restored['final_guess'] as Map)['choices'] as List)
          .cast<Map>();
      _expect(choices.length == 4, 'reconnect restores four persisted choices');
      final keyword = secrets[normal]['word_vi'];
      final choice = outcome == _Outcome.correctGuess
          ? choices.firstWhere((value) => value['word_vi'] == keyword)
          : choices.firstWhere((value) => value['word_vi'] != keyword);
      await clients[impostor].rpc<Object?>(
        'submit_final_guess',
        params: {'p_choice_id': choice['choice_id']},
      );
      await expectResult(
        outcome == _Outcome.correctGuess ? 'impostor' : 'normal',
        outcome == _Outcome.correctGuess
            ? 'impostor_final_guess_correct'
            : 'impostor_final_guess_wrong',
      );
    }

    await reconnect(1);
    final restoredResult = await game(1);
    _expect(restoredResult['status'] == 'result', 'result reconnect');
    final reward = (restoredResult['result'] as Map)['reward'] as Map;
    _expect(
      reward['coins_gained'] == 10 || reward['coins_gained'] == 20,
      'caller-only completion/winner coins',
    );
    await _securityChecks();
    await _expectPostgrestFailure(
      () => clients[1].rpc<Object?>('play_again'),
      'non-host cannot Play Again',
    );
    await clients[0].rpc<Object?>('play_again');
    await clients[0].rpc<Object?>('play_again');
    for (var i = 0; i < clients.length; i++) {
      final room = Map<String, dynamic>.from(
        await clients[i].rpc<Object?>('get_current_room') as Map,
      );
      _expect(room['status'] == 'waiting', 'client $i returned to lobby');
      final members = (room['members'] as List).cast<Map>();
      if (i == 0) {
        _expect(
          members
              .where((member) => member['is_host'] != true)
              .every((member) => member['is_ready'] == false),
          'non-host readiness reset',
        );
      }
      _expect(
        await clients[i].rpc<Object?>('get_current_game') == null,
        'no active game after Play Again',
      );
    }
    _expect(
      payloads.every((payload) {
        final text = payload.toString().toLowerCase();
        return !text.contains('keyword') &&
            !text.contains('word_') &&
            !text.contains('reward') &&
            !text.contains('choice');
      }),
      'broadcast contains no game secrets or reward data',
    );
  }

  Future<void> _securityChecks() async {
    await _expectPostgrestFailure(
      () => clients[0].from('game_rewards').select(),
      'reward ledger cannot be read directly',
    );
    await _expectPostgrestFailure(
      () => clients[0]
          .from('profiles')
          .update({'xp': 999999, 'coins': 999999, 'level': 999})
          .eq('id', ids[0]),
      'profile economy cannot be mutated',
    );
    await _expectPostgrestFailure(
      () => clients[0]
          .from('games')
          .update({'winner_team': 'impostor'})
          .eq('room_id', roomId),
      'winner cannot be mutated',
    );
    await _expectPostgrestFailure(
      () => clients[0].rpc<Object?>('resolve_game_result'),
      'private resolution cannot be called',
    );
  }

  Future<void> reconnect(int index) async {
    final refreshToken = clients[index].auth.currentSession!.refreshToken!;
    await clients[index].dispose();
    final replacement = SupabaseClient(url, key);
    await replacement.auth.setSession(refreshToken);
    clients[index] = replacement;
  }

  Future<void> vote(int voter, int target) => clients[voter].rpc<Object?>(
    'submit_vote',
    params: {'p_target_player_id': ids[target]},
  );

  Future<Map<String, dynamic>> game(int index) async =>
      Map<String, dynamic>.from(
        await clients[index].rpc<Object?>('get_current_game') as Map,
      );

  Future<void> expectStatus(String status) async {
    for (var i = 0; i < clients.length; i++) {
      _expect((await game(i))['status'] == status, 'client $i status $status');
    }
  }

  Future<void> expectResult(String winner, String reason) async {
    for (var i = 0; i < clients.length; i++) {
      final snapshot = await game(i);
      final result = snapshot['result'] as Map;
      _expect(snapshot['status'] == 'result', 'client $i reached result');
      _expect(result['winner_team'] == winner, 'client $i winner');
      _expect(result['reason'] == reason, 'client $i reason');
      _expect(result['reward'] != null, 'client $i owns reward summary');
      _expect(
        (snapshot['participants'] as List).cast<Map>().every(
          (participant) => participant['role'] != null,
        ),
        'client $i sees result roles',
      );
    }
  }

  Future<void> dispose() async {
    for (final client in clients) {
      await client.removeAllChannels();
      await client.dispose();
    }
  }
}

Future<void> _expectPostgrestFailure(
  Future<Object?> Function() operation,
  String label,
) async {
  try {
    await operation();
  } on PostgrestException {
    return;
  }
  throw StateError('Failed: $label');
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

void _expect(bool value, String label) {
  if (!value) throw StateError('Failed: $label');
}
