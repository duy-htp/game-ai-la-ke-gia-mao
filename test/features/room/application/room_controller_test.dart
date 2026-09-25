import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_controller.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_state.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/application/room_action_state.dart';
import 'package:ai_la_ke_gia_mao/features/room/application/room_controller.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/lobby_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

ProviderContainer _container(FakeRoomRepository rooms) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: 'http://127.0.0.1:54321',
          supabaseAnonKey: 'test-key',
        ),
      ),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(profile: sampleProfile),
      ),
      roomRepositoryProvider.overrideWithValue(rooms),
      gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
      createRequestIdProvider.overrideWithValue(
        () => '90000000-0000-4000-8000-000000000001',
      ),
    ],
  );
}

Future<void> _initialize(ProviderContainer container) async {
  await container.read(appSessionControllerProvider.notifier).initialize();
}

void main() {
  test('create room success updates authoritative application state', () async {
    final rooms = FakeRoomRepository();
    final container = _container(rooms);
    addTearDown(container.dispose);
    await _initialize(container);

    await container
        .read(roomControllerProvider.notifier)
        .createRoom(maxPlayers: 6);

    expect(rooms.createCalls, 1);
    expect(rooms.submittedMaxPlayers, 6);
    expect(
      (container.read(appSessionControllerProvider) as AppSessionReady).room,
      sampleRoom,
    );
  });

  test('invalid max players is rejected before repository call', () async {
    final rooms = FakeRoomRepository();
    final container = _container(rooms);
    addTearDown(container.dispose);
    await _initialize(container);

    await container
        .read(roomControllerProvider.notifier)
        .createRoom(maxPlayers: 2);

    expect(rooms.createCalls, 0);
    expect(
      (container.read(roomControllerProvider) as RoomActionError).error,
      isA<InvalidMaxPlayersAppError>(),
    );
  });

  test('create retry reuses its idempotency key after failure', () async {
    final rooms = FakeRoomRepository(
      createError: const RoomOperationAppError(),
    );
    final container = _container(rooms);
    addTearDown(container.dispose);
    await _initialize(container);
    final controller = container.read(roomControllerProvider.notifier);

    await controller.createRoom();
    final firstRequestId = rooms.submittedRequestId;
    rooms.createError = null;
    await controller.createRoom();

    expect(rooms.submittedRequestId, firstRequestId);
    expect(rooms.createCalls, 2);
  });

  test(
    'join normalizes code and maps success into application state',
    () async {
      final rooms = FakeRoomRepository();
      final container = _container(rooms);
      addTearDown(container.dispose);
      await _initialize(container);

      await container
          .read(roomControllerProvider.notifier)
          .joinRoom(' ab2k9p ');

      expect(rooms.submittedCode?.value, 'AB2K9P');
      expect(
        (container.read(appSessionControllerProvider) as AppSessionReady).room,
        sampleRoom,
      );
    },
  );

  test('invalid code never calls repository', () async {
    final rooms = FakeRoomRepository();
    final container = _container(rooms);
    addTearDown(container.dispose);
    await _initialize(container);

    await container.read(roomControllerProvider.notifier).joinRoom('O0I1L!');

    expect(rooms.joinCalls, 0);
    expect(
      (container.read(roomControllerProvider) as RoomActionError).error,
      isA<InvalidRoomCodeAppError>(),
    );
  });

  for (final error in [
    const RoomNotFoundAppError(),
    const RoomFullAppError(),
    const AlreadyInAnotherRoomAppError(),
  ]) {
    test('join preserves typed ${error.code} error', () async {
      final rooms = FakeRoomRepository(joinError: error);
      final container = _container(rooms);
      addTearDown(container.dispose);
      await _initialize(container);

      await container.read(roomControllerProvider.notifier).joinRoom('AB2K9P');

      expect(
        (container.read(roomControllerProvider) as RoomActionError).error.code,
        error.code,
      );
    });
  }

  test('leave clears current room and is safe to retry', () async {
    final rooms = FakeRoomRepository(currentRoom: sampleRoom);
    final container = _container(rooms);
    addTearDown(container.dispose);
    await _initialize(container);
    final controller = container.read(roomControllerProvider.notifier);

    await controller.leaveRoom();
    await controller.leaveRoom();

    expect(rooms.leaveCalls, 2);
    expect(
      (container.read(appSessionControllerProvider) as AppSessionReady).room,
      isNull,
    );
  });

  test(
    'set ready sends idempotent target state and applies snapshot',
    () async {
      final rooms = FakeRoomRepository(currentRoom: sampleRoom);
      final container = _container(rooms);
      addTearDown(container.dispose);
      await _initialize(container);

      await container.read(roomControllerProvider.notifier).setReady(true);
      await container.read(roomControllerProvider.notifier).setReady(true);

      expect(rooms.readyCalls, 2);
      expect(rooms.submittedReady, isTrue);
      expect(container.read(roomControllerProvider), isA<RoomActionIdle>());
    },
  );

  test('ready failure remains a typed action error', () async {
    final rooms = FakeRoomRepository(
      currentRoom: sampleRoom,
      readyError: const RoomOperationAppError(),
    );
    final container = _container(rooms);
    addTearDown(container.dispose);
    await _initialize(container);

    await container.read(roomControllerProvider.notifier).setReady(true);

    expect(container.read(roomControllerProvider), isA<RoomActionError>());
  });

  test('host saves complete settings as one state-setting request', () async {
    final rooms = FakeRoomRepository(currentRoom: sampleRoom);
    final container = _container(rooms);
    addTearDown(container.dispose);
    await _initialize(container);
    const settings = LobbySettings(
      impostorCount: 1,
      categoryKey: 'food',
      clueSeconds: 45,
      discussionSeconds: 120,
    );

    await container
        .read(roomControllerProvider.notifier)
        .updateSettings(settings);

    expect(rooms.settingsCalls, 1);
    expect(rooms.submittedSettings, settings);
  });
}
