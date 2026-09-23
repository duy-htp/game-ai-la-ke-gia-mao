import 'package:ai_la_ke_gia_mao/app/app.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders all milestone-one actions without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(environment: AppEnvironment.development),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI LÀ KẺ GIẢ MẠO?'), findsOneWidget);
    expect(find.byKey(const Key('create-room-button')), findsOneWidget);
    expect(find.byKey(const Key('join-room-button')), findsOneWidget);
    expect(find.text('Hồ sơ'), findsOneWidget);
    expect(find.text('Cửa hàng'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable primary action is harmless and explained', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(environment: AppEnvironment.development),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-room-button')));
    await tester.pump();

    expect(
      find.text('Tính năng sẽ có trong cột mốc tiếp theo.'),
      findsOneWidget,
    );
  });
}
