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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

Widget _testApp({Locale? locale, PlayerProfile? profile}) {
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
      roomRepositoryProvider.overrideWithValue(FakeRoomRepository()),
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
}
