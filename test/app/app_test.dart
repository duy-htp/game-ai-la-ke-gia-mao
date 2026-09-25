import 'package:ai_la_ke_gia_mao/app/app.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/core/router/app_router.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/home/presentation/home_screen.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/player_profile.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/presentation/onboarding_screen.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_snapshot.dart';
import 'package:ai_la_ke_gia_mao/features/game/presentation/role_reveal_screen.dart';
import 'package:ai_la_ke_gia_mao/features/game/presentation/clue_screen.dart';
import 'package:ai_la_ke_gia_mao/features/game/presentation/discussion_screen.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_status.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

Widget _testApp({
  Locale? locale,
  PlayerProfile? profile,
  RoomSnapshot? room,
  GameSnapshot? game,
}) {
  return ProviderScope(
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
        FakeProfileRepository(profile: profile ?? sampleProfile),
      ),
      roomRepositoryProvider.overrideWithValue(
        FakeRoomRepository(currentRoom: room),
      ),
      gameRepositoryProvider.overrideWithValue(
        FakeGameRepository(currentGame: game),
      ),
    ],
    child: App(locale: locale),
  );
}

void main() {
  testWidgets('builds the application shell with MaterialApp.router', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byKey(HomeScreen.screenKey), findsOneWidget);
  });

  testWidgets('uses Vietnamese as the default locale', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('TẠO PHÒNG'), findsOneWidget);
    expect(find.text('VÀO PHÒNG'), findsOneWidget);
  });

  testWidgets('supports the English locale', (tester) async {
    await tester.pumpWidget(_testApp(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('CREATE ROOM'), findsOneWidget);
    expect(find.text('JOIN ROOM'), findsOneWidget);
  });

  testWidgets('router starts on the Home route', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.byKey(HomeScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('game-title')), findsOneWidget);
  });

  testWidgets('router guard prevents bypassing onboarding', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            environment: AppEnvironment.development,
            supabaseUrl: 'http://127.0.0.1:54321',
            supabaseAnonKey: 'test-key',
          ),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        roomRepositoryProvider.overrideWithValue(FakeRoomRepository()),
        gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(OnboardingScreen.screenKey), findsOneWidget);
    container.read(appRouterProvider).go('/');
    await tester.pumpAndSettle();
    expect(find.byKey(OnboardingScreen.screenKey), findsOneWidget);
    expect(find.byKey(HomeScreen.screenKey), findsNothing);
  });

  testWidgets(
    'startup with active game restores Role Reveal instead of Lobby',
    (tester) async {
      await tester.pumpWidget(_testApp(room: sampleRoom, game: sampleGame));
      await tester.pumpAndSettle();
      expect(find.byKey(RoleRevealScreen.screenKey), findsOneWidget);
      expect(find.text('PHÒNG CHỜ'), findsNothing);
    },
  );

  testWidgets('server clue phase routes to ClueScreen with own-turn input', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 26);
    final game = GameSnapshot(
      gameId: sampleGame.gameId,
      roomId: sampleGame.roomId,
      roundNumber: 1,
      status: GameStatus.clue,
      phaseStartedAt: now,
      phaseEndsAt: now.add(const Duration(seconds: 30)),
      serverNow: now,
      revision: 5,
      participants: sampleGame.participants,
      turns: [
        GameTurnSnapshot(
          turnId: 1,
          turnIndex: 1,
          playerId: sampleProfile.id,
          status: GameTurnStatus.active,
          startedAt: now,
          endsAt: now.add(const Duration(seconds: 30)),
          completedAt: null,
          clueText: null,
        ),
      ],
    );
    await tester.pumpWidget(_testApp(room: sampleRoom, game: game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(ClueScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('clue-input')), findsOneWidget);
    expect(find.text('ĐẾN LƯỢT BẠN'), findsOneWidget);
  });

  testWidgets('server discussion phase routes to minimal DiscussionScreen', (
    tester,
  ) async {
    final game = GameSnapshot(
      gameId: sampleGame.gameId,
      roomId: sampleGame.roomId,
      roundNumber: 1,
      status: GameStatus.discussion,
      phaseStartedAt: sampleGame.phaseStartedAt,
      phaseEndsAt: sampleGame.phaseEndsAt,
      serverNow: sampleGame.serverNow,
      revision: 9,
      participants: sampleGame.participants,
      turns: const [],
    );
    await tester.pumpWidget(
      _testApp(locale: const Locale('en'), room: sampleRoom, game: game),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(DiscussionScreen.screenKey), findsOneWidget);
    expect(
      find.text('Voting will follow in the next milestone.'),
      findsOneWidget,
    );
  });
}
