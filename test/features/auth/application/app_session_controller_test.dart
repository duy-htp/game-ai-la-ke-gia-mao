import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_controller.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_state.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_snapshot.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_status.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

ProviderContainer _container({
  required FakeAuthRepository auth,
  required FakeProfileRepository profiles,
  FakeRoomRepository? rooms,
}) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: 'http://127.0.0.1:54321',
          supabaseAnonKey: 'test-publishable-key',
        ),
      ),
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profiles),
      roomRepositoryProvider.overrideWithValue(rooms ?? FakeRoomRepository()),
      gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
    ],
  );
}

void main() {
  test('profile exists transitions to authenticated ready', () async {
    final container = _container(
      auth: FakeAuthRepository(),
      profiles: FakeProfileRepository(profile: sampleProfile),
    );
    addTearDown(container.dispose);

    await container.read(appSessionControllerProvider.notifier).initialize();

    expect(
      container.read(appSessionControllerProvider),
      isA<AppSessionReady>(),
    );
  });

  test('profile absent transitions to authenticated needs profile', () async {
    final container = _container(
      auth: FakeAuthRepository(),
      profiles: FakeProfileRepository(),
    );
    addTearDown(container.dispose);

    await container.read(appSessionControllerProvider.notifier).initialize();

    expect(
      container.read(appSessionControllerProvider),
      isA<AppSessionNeedsProfile>(),
    );
  });

  test('profile query failure never becomes profile absent', () async {
    final auth = FakeAuthRepository();
    final container = _container(
      auth: auth,
      profiles: FakeProfileRepository(fetchError: const ProfileLoadAppError()),
    );
    addTearDown(container.dispose);

    await container.read(appSessionControllerProvider.notifier).initialize();

    expect(
      container.read(appSessionControllerProvider),
      isA<AppSessionRecoverableError>(),
    );
    expect(auth.calls, 1);
  });

  test('active room is restored during application initialization', () async {
    final container = _container(
      auth: FakeAuthRepository(),
      profiles: FakeProfileRepository(profile: sampleProfile),
      rooms: FakeRoomRepository(currentRoom: sampleRoom),
    );
    addTearDown(container.dispose);

    await container.read(appSessionControllerProvider.notifier).initialize();

    final state = container.read(appSessionControllerProvider);
    expect((state as AppSessionReady).room, sampleRoom);
  });

  test('no active room restores ready state with no room', () async {
    final container = _container(
      auth: FakeAuthRepository(),
      profiles: FakeProfileRepository(profile: sampleProfile),
      rooms: FakeRoomRepository(),
    );
    addTearDown(container.dispose);

    await container.read(appSessionControllerProvider.notifier).initialize();

    final state = container.read(appSessionControllerProvider);
    expect((state as AppSessionReady).room, isNull);
  });

  test('room lookup failure remains a recoverable error', () async {
    final container = _container(
      auth: FakeAuthRepository(),
      profiles: FakeProfileRepository(profile: sampleProfile),
      rooms: FakeRoomRepository(loadError: const RoomOperationAppError()),
    );
    addTearDown(container.dispose);

    await container.read(appSessionControllerProvider.notifier).initialize();

    expect(
      container.read(appSessionControllerProvider),
      isA<AppSessionRecoverableError>(),
    );
  });

  test('successful onboarding trims input and transitions to ready', () async {
    final profiles = FakeProfileRepository();
    final container = _container(
      auth: FakeAuthRepository(),
      profiles: profiles,
    );
    addTearDown(container.dispose);
    final controller = container.read(appSessionControllerProvider.notifier);
    await controller.initialize();

    await controller.completeProfile(
      username: '  Dũng  ',
      avatarId: 'avatar_01',
    );

    expect(profiles.submittedUsername, 'Dũng');
    expect(profiles.completeCalls, 1);
    expect(
      container.read(appSessionControllerProvider),
      isA<AppSessionReady>(),
    );
  });

  test('onboarding failure remains on onboarding with a typed error', () async {
    final profiles = FakeProfileRepository(
      completeError: const ProfileCreationAppError(),
    );
    final container = _container(
      auth: FakeAuthRepository(),
      profiles: profiles,
    );
    addTearDown(container.dispose);
    final controller = container.read(appSessionControllerProvider.notifier);
    await controller.initialize();

    await controller.completeProfile(username: 'Dũng', avatarId: 'avatar_01');

    final state = container.read(appSessionControllerProvider);
    expect(state, isA<AppSessionNeedsProfile>());
    expect(
      (state as AppSessionNeedsProfile).submissionError,
      isA<ProfileCreationAppError>(),
    );
  });

  test('invalid input does not call profile repository', () async {
    final profiles = FakeProfileRepository();
    final container = _container(
      auth: FakeAuthRepository(),
      profiles: profiles,
    );
    addTearDown(container.dispose);
    final controller = container.read(appSessionControllerProvider.notifier);
    await controller.initialize();

    await controller.completeProfile(username: ' ', avatarId: 'avatar_99');

    expect(profiles.completeCalls, 0);
    final state = container.read(appSessionControllerProvider);
    expect(
      (state as AppSessionNeedsProfile).submissionError,
      isA<InvalidUsernameAppError>(),
    );
  });

  test(
    'room and game revisions never regress but same revision may refresh',
    () async {
      final container = _container(
        auth: FakeAuthRepository(),
        profiles: FakeProfileRepository(profile: sampleProfile),
        rooms: FakeRoomRepository(currentRoom: sampleRoom),
      );
      addTearDown(container.dispose);
      final controller = container.read(appSessionControllerProvider.notifier);
      await controller.initialize();

      RoomSnapshot room(int revision, int maxPlayers) => RoomSnapshot(
        roomId: sampleRoom.roomId,
        code: sampleRoom.code,
        gameType: sampleRoom.gameType,
        status: sampleRoom.status,
        maxPlayers: maxPlayers,
        hostId: sampleRoom.hostId,
        members: sampleRoom.members,
        revision: revision,
      );
      GameSnapshot game(int revision, GameStatus status) => GameSnapshot(
        gameId: sampleGame.gameId,
        roomId: sampleGame.roomId,
        roundNumber: sampleGame.roundNumber,
        status: status,
        phaseStartedAt: sampleGame.phaseStartedAt,
        phaseEndsAt: sampleGame.phaseEndsAt,
        revision: revision,
        participants: sampleGame.participants,
        serverNow: sampleGame.serverNow,
        turns: const [],
      );
      controller.setRoom(room(20, 6));
      controller.setRoom(room(19, 8));
      controller.setRoom(room(20, 7));
      controller.setGame(game(20, GameStatus.clue));
      controller.setGame(game(19, GameStatus.discussion));
      controller.setGame(game(20, GameStatus.voting));

      final state =
          container.read(appSessionControllerProvider) as AppSessionReady;
      expect(state.room!.revision, 20);
      expect(
        state.room!.maxPlayers,
        7,
        reason: 'same revision refreshes caller-safe fields',
      );
      expect(state.game!.revision, 20);
      expect(state.game!.status, GameStatus.voting);
    },
  );
}
