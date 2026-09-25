import 'package:ai_la_ke_gia_mao/features/game/domain/game_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/player_game_secret.dart';
import 'package:ai_la_ke_gia_mao/features/game/presentation/role_reveal_screen.dart';
import 'package:ai_la_ke_gia_mao/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

Future<void> pumpRole(
  WidgetTester tester,
  PlayerGameSecret secret, {
  Locale locale = const Locale('vi'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameRepositoryProvider.overrideWithValue(
          FakeGameRepository(secret: secret),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RoleRevealScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'short hold does not reveal and one second hold reveals normal keyword',
    (tester) async {
      await pumpRole(
        tester,
        const PlayerGameSecret(
          role: PlayerRole.normal,
          wordVi: 'Dưa hấu',
          wordEn: 'Watermelon',
        ),
      );
      final center = tester.getCenter(find.byKey(const Key('hold-to-reveal')));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 900));
      await gesture.up();
      await tester.pump();
      expect(find.byKey(const Key('secret-keyword')), findsNothing);
      final second = await tester.startGesture(center);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Dưa hấu'), findsOneWidget);
      await second.up();
    },
  );
  testWidgets('impostor never renders keyword widget', (tester) async {
    await pumpRole(tester, const PlayerGameSecret(role: PlayerRole.impostor));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('hold-to-reveal'))),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('impostor-hint')), findsOneWidget);
    expect(find.byKey(const Key('secret-keyword')), findsNothing);
    await gesture.up();
  });
  testWidgets('secret auto hides and remembered hides immediately', (
    tester,
  ) async {
    await pumpRole(
      tester,
      const PlayerGameSecret(
        role: PlayerRole.normal,
        wordVi: 'Dưa hấu',
        wordEn: 'Watermelon',
      ),
    );
    var gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('hold-to-reveal'))),
    );
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const Key('revealed-secret')), findsNothing);
    gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('hold-to-reveal'))),
    );
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.tap(find.byKey(const Key('remembered-button')));
    await tester.pump();
    expect(find.byKey(const Key('revealed-secret')), findsNothing);
  });
  testWidgets('English renders corresponding selected concept on small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpRole(
      tester,
      const PlayerGameSecret(
        role: PlayerRole.normal,
        wordVi: 'Dưa hấu',
        wordEn: 'Watermelon',
      ),
      locale: const Locale('en'),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('hold-to-reveal'))),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Watermelon'), findsOneWidget);
    await gesture.up();
  });
  testWidgets('background hides secret and resume keeps it hidden', (
    tester,
  ) async {
    await pumpRole(
      tester,
      const PlayerGameSecret(
        role: PlayerRole.normal,
        wordVi: 'Dưa hấu',
        wordEn: 'Watermelon',
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('hold-to-reveal'))),
    );
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    expect(find.byKey(const Key('revealed-secret')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byKey(const Key('revealed-secret')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('revealed-secret')), findsNothing);
  });
}
