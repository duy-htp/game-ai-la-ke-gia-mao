import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_controller.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_state.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
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
}
