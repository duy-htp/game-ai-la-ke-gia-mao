import 'package:ai_la_ke_gia_mao/app/app.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

Widget _testScope(Widget child) {
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
        FakeProfileRepository(profile: sampleProfile),
      ),
    ],
    child: child,
  );
}

void main() {
  testWidgets('renders all milestone-one actions without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testScope(const App()));
    await tester.pumpAndSettle();

    expect(find.text('AI LÀ KẺ GIẢ MẠO?'), findsOneWidget);
    expect(find.byKey(const Key('create-room-button')), findsOneWidget);
    expect(find.byKey(const Key('join-room-button')), findsOneWidget);
    expect(find.text('Hồ sơ'), findsOneWidget);
    expect(find.text('Cửa hàng'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.text('Dũng'), findsOneWidget);
    expect(find.text('Cấp 1'), findsOneWidget);
    expect(find.text('🪙 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable primary action is harmless and explained', (
    tester,
  ) async {
    await tester.pumpWidget(_testScope(const App()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-room-button')));
    await tester.pump();

    expect(
      find.text('Tính năng sẽ có trong cột mốc tiếp theo.'),
      findsOneWidget,
    );
  });
}
