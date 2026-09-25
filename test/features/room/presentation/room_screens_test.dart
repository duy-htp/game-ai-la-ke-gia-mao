import 'package:ai_la_ke_gia_mao/app/app.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/core/router/app_router.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/home/presentation/home_screen.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/presentation/create_room_screen.dart';
import 'package:ai_la_ke_gia_mao/features/room/presentation/join_room_screen.dart';
import 'package:ai_la_ke_gia_mao/features/room/presentation/room_screen.dart';
import 'package:flutter/material.dart';
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
    ],
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeRoomRepository rooms, {
  Locale? locale,
}) async {
  final container = _container(rooms);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: App(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('CreateRoomScreen creates room with default capacity', (
    tester,
  ) async {
    final rooms = FakeRoomRepository();
    await _pump(tester, rooms);

    await tester.tap(find.byKey(const Key('create-room-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(CreateRoomScreen.screenKey), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    await tester.tap(find.byKey(const Key('create-room-submit')));
    await tester.pumpAndSettle();

    expect(rooms.submittedMaxPlayers, 6);
    expect(find.byKey(RoomScreen.screenKey), findsOneWidget);
  });

  testWidgets('JoinRoomScreen validates malformed code locally', (
    tester,
  ) async {
    final rooms = FakeRoomRepository();
    await _pump(tester, rooms);

    await tester.tap(find.byKey(const Key('join-room-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(JoinRoomScreen.screenKey), findsOneWidget);
    await tester.enterText(find.byKey(const Key('room-code-field')), 'O0I1L!');
    await tester.tap(find.byKey(const Key('join-room-submit')));
    await tester.pumpAndSettle();

    expect(rooms.joinCalls, 0);
    expect(find.text('Mã phòng phải gồm đúng 6 ký tự hợp lệ.'), findsOneWidget);
  });

  testWidgets('JoinRoomScreen maps room-not-found without raw RPC errors', (
    tester,
  ) async {
    final rooms = FakeRoomRepository(joinError: const RoomNotFoundAppError());
    await _pump(tester, rooms);
    await tester.tap(find.byKey(const Key('join-room-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('room-code-field')), 'AB2K9P');
    await tester.tap(find.byKey(const Key('join-room-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Không tìm thấy phòng.'), findsOneWidget);
  });

  testWidgets('active room guard restores RoomScreen and blocks Home', (
    tester,
  ) async {
    final rooms = FakeRoomRepository(currentRoom: sampleRoom);
    final container = await _pump(tester, rooms);

    expect(find.byKey(RoomScreen.screenKey), findsOneWidget);
    container.read(appRouterProvider).go('/');
    await tester.pumpAndSettle();
    expect(find.byKey(RoomScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeScreen.screenKey), findsNothing);
  });

  testWidgets('RoomScreen shows safe room data and leaving returns Home', (
    tester,
  ) async {
    final rooms = FakeRoomRepository(currentRoom: sampleRoom);
    await _pump(tester, rooms);

    expect(find.text('AB2K9P'), findsOneWidget);
    expect(find.text('Dũng'), findsOneWidget);
    expect(find.text('Chủ phòng'), findsOneWidget);
    expect(find.text('1/6'), findsOneWidget);

    await tester.tap(find.byKey(const Key('leave-room-button')));
    await tester.pumpAndSettle();

    expect(rooms.leaveCalls, 1);
    expect(find.byKey(HomeScreen.screenKey), findsOneWidget);
  });

  testWidgets('room screens support English and a small viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      FakeRoomRepository(currentRoom: sampleRoom),
      locale: const Locale('en'),
    );

    expect(find.text('WAITING ROOM'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('LEAVE ROOM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
