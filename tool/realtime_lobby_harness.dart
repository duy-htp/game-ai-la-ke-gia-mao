import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError(
      'Usage: dart run tool/realtime_lobby_harness.dart URL ANON_KEY',
    );
  }
  final host = SupabaseClient(args[0], args[1]);
  final member = SupabaseClient(args[0], args[1]);
  RealtimeChannel? hostChannel;
  RealtimeChannel? memberChannel;
  try {
    await host.auth.signInAnonymously();
    await member.auth.signInAnonymously();
    await host.rpc<Object?>(
      'complete_profile',
      params: {'p_username': 'Realtime Host', 'p_avatar_id': 'avatar_01'},
    );
    await member.rpc<Object?>(
      'complete_profile',
      params: {'p_username': 'Realtime Member', 'p_avatar_id': 'avatar_02'},
    );
    final room = Map<String, dynamic>.from(
      await host.rpc<Object?>(
        'create_room',
        params: {
          'p_game_type': 'impostor',
          'p_max_players': 6,
          'p_request_id': const Uuid().v4(),
        },
      ) as Map,
    );
    final roomId = room['room_id']! as String;
    final code = room['code']! as String;
    final hostId = host.auth.currentUser!.id;
    final memberId = member.auth.currentUser!.id;

    final joinInvalidation = Completer<void>();
    final presenceSeen = Completer<void>();
    hostChannel = host.channel(
      'room:$roomId',
      opts: RealtimeChannelConfig(private: true, enabled: true, key: hostId),
    );
    hostChannel
        .onBroadcast(
          event: 'room_changed',
          callback: (_) {
            if (!joinInvalidation.isCompleted) joinInvalidation.complete();
          },
        )
        .onPresenceSync((_) {
          if (hostChannel!.presenceState().any(
                (state) => state.key == memberId,
              ) &&
              !presenceSeen.isCompleted) {
            presenceSeen.complete();
          }
        });
    await _subscribe(hostChannel);
    await hostChannel.track({'user_id': hostId});

    await member.rpc<Object?>('join_room', params: {'p_room_code': code});
    await joinInvalidation.future.timeout(const Duration(seconds: 8));
    final afterJoin = Map<String, dynamic>.from(
      await host.rpc<Object?>('get_current_room') as Map,
    );
    _expect(
      (afterJoin['members'] as List).length == 2,
      'join snapshot convergence',
    );

    memberChannel = member.channel(
      'room:$roomId',
      opts: RealtimeChannelConfig(private: true, enabled: true, key: memberId),
    );
    await _subscribe(memberChannel);
    await memberChannel.track({'user_id': memberId});
    await presenceSeen.future.timeout(const Duration(seconds: 8));

    await host.removeChannel(hostChannel);
    hostChannel = null;
    await member.rpc<Object?>('set_ready', params: {'p_is_ready': true});
    final afterReconnect = Map<String, dynamic>.from(
      await host.rpc<Object?>('get_current_room') as Map,
    );
    final memberRow = (afterReconnect['members'] as List)
        .cast<Map>()
        .firstWhere((row) => row['player_id'] == memberId);
    _expect(memberRow['is_ready'] == true, 'reconnect authoritative refetch');

    final settingsInvalidation = Completer<void>();
    hostChannel = host.channel(
      'room:$roomId',
      opts: RealtimeChannelConfig(private: true, enabled: true, key: hostId),
    );
    hostChannel.onBroadcast(
      event: 'room_changed',
      callback: (_) {
        if (!settingsInvalidation.isCompleted) settingsInvalidation.complete();
      },
    );
    await _subscribe(hostChannel);
    await hostChannel.track({'user_id': hostId});
    await host.rpc<Object?>(
      'update_room_settings',
      params: {
        'p_impostor_count': 1,
        'p_category_key': 'food',
        'p_clue_seconds': 45,
        'p_discussion_seconds': 120,
      },
    );
    await settingsInvalidation.future.timeout(const Duration(seconds: 8));
    final finalSnapshot = Map<String, dynamic>.from(
      await member.rpc<Object?>('get_current_room') as Map,
    );
    _expect(
      (finalSnapshot['settings'] as Map)['category_key'] == 'food',
      'settings convergence',
    );
    final resetMember = (finalSnapshot['members'] as List)
        .cast<Map>()
        .firstWhere((row) => row['player_id'] == memberId);
    _expect(resetMember['is_ready'] == false, 'ready reset convergence');

    final leaveInvalidation = Completer<void>();
    memberChannel.onBroadcast(
      event: 'room_changed',
      callback: (_) {
        if (!leaveInvalidation.isCompleted) leaveInvalidation.complete();
      },
    );
    await host.rpc<Object?>('leave_room');
    await leaveInvalidation.future.timeout(const Duration(seconds: 8));
    final afterHostLeave = Map<String, dynamic>.from(
      await member.rpc<Object?>('get_current_room') as Map,
    );
    _expect(afterHostLeave['host_id'] == memberId, 'host transfer convergence');
    // ignore: avoid_print
    print(
      'PASS: realtime join/settings/leave, presence and reconnect converged',
    );
  } finally {
    if (hostChannel != null) await host.removeChannel(hostChannel);
    if (memberChannel != null) await member.removeChannel(memberChannel);
    await host.dispose();
    await member.dispose();
  }
}

Future<void> _subscribe(RealtimeChannel channel) {
  final completer = Completer<void>();
  channel.subscribe((status, error) {
    if (status == RealtimeSubscribeStatus.subscribed &&
        !completer.isCompleted) {
      completer.complete();
    } else if ((status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) &&
        !completer.isCompleted) {
      completer.completeError(
        StateError('Realtime subscription failed: $error'),
      );
    }
  });
  return completer.future.timeout(const Duration(seconds: 8));
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError('Failed: $message');
}
