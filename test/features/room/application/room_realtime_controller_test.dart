import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_controller.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/application/room_realtime_controller.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_realtime.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

ProviderContainer containerFor(FakeRoomRepository rooms) => ProviderContainer(
  overrides: [
    appConfigProvider.overrideWithValue(
      const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: 'http://127.0.0.1:54321',
        supabaseAnonKey: 'test',
      ),
    ),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    profileRepositoryProvider.overrideWithValue(
      FakeProfileRepository(profile: sampleProfile),
    ),
    roomRepositoryProvider.overrideWithValue(rooms),
    gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
  ],
);

void main() {
  test('duplicate invalidations are coalesced into one refresh', () async {
    final rooms = FakeRoomRepository(currentRoom: sampleRoom);
    final container = containerFor(rooms);
    addTearDown(container.dispose);
    await container.read(appSessionControllerProvider.notifier).initialize();
    final controller = container.read(roomRealtimeControllerProvider.notifier);
    await controller.start(sampleRoom.roomId);
    final baseline = rooms.loadCalls;

    for (var i = 0; i < 20; i++) {
      rooms.lastRealtimeSession!.controller.add(const RoomInvalidated());
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(rooms.loadCalls, baseline + 1);
  });

  test('repeated start owns one effective subscription', () async {
    final rooms = FakeRoomRepository(currentRoom: sampleRoom);
    final container = containerFor(rooms);
    addTearDown(container.dispose);
    await container.read(appSessionControllerProvider.notifier).initialize();
    final controller = container.read(roomRealtimeControllerProvider.notifier);
    for (var i = 0; i < 10; i++) {
      await controller.start(sampleRoom.roomId);
    }
    expect(rooms.realtimeConnectCalls, 1);
  });

  test('presence is UX-only and filters non-members', () async {
    final rooms = FakeRoomRepository(currentRoom: sampleRoom);
    final container = containerFor(rooms);
    addTearDown(container.dispose);
    await container.read(appSessionControllerProvider.notifier).initialize();
    await container
        .read(roomRealtimeControllerProvider.notifier)
        .start(sampleRoom.roomId);

    rooms.lastRealtimeSession!.controller.add(
      RoomPresenceChanged({sampleProfile.id, 'outsider'}),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(roomRealtimeControllerProvider).onlinePlayerIds, {
      sampleProfile.id,
    });
  });

  test('reconnect triggers authoritative refresh', () async {
    final rooms = FakeRoomRepository(currentRoom: sampleRoom);
    final container = containerFor(rooms);
    addTearDown(container.dispose);
    await container.read(appSessionControllerProvider.notifier).initialize();
    await container
        .read(roomRealtimeControllerProvider.notifier)
        .start(sampleRoom.roomId);
    final baseline = rooms.loadCalls;

    rooms.lastRealtimeSession!.controller
      ..add(const RoomConnectionChanged(RoomConnectionState.reconnecting))
      ..add(const RoomConnectionChanged(RoomConnectionState.connected));
    await Future<void>.delayed(Duration.zero);

    expect(rooms.loadCalls, baseline + 1);
  });

  test('stop disposes subscription', () async {
    final rooms = FakeRoomRepository(currentRoom: sampleRoom);
    final container = containerFor(rooms);
    addTearDown(container.dispose);
    await container.read(appSessionControllerProvider.notifier).initialize();
    final controller = container.read(roomRealtimeControllerProvider.notifier);
    await controller.start(sampleRoom.roomId);
    final session = rooms.lastRealtimeSession!;

    await controller.stop();

    expect(session.controller.isClosed, isTrue);
  });
}
