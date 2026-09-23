import 'package:ai_la_ke_gia_mao/app/app.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testApp({Locale? locale}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(environment: AppEnvironment.development),
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
}
