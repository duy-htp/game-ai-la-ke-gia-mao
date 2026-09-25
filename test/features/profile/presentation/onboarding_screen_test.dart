import 'package:ai_la_ke_gia_mao/app/app.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/home/presentation/home_screen.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/presentation/onboarding_screen.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

Widget _app(FakeProfileRepository profiles, {Locale? locale}) {
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
      profileRepositoryProvider.overrideWithValue(profiles),
      roomRepositoryProvider.overrideWithValue(FakeRoomRepository()),
    ],
    child: App(locale: locale),
  );
}

void main() {
  testWidgets('profile absent shows Vietnamese onboarding', (tester) async {
    await tester.pumpWidget(_app(FakeProfileRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(OnboardingScreen.screenKey), findsOneWidget);
    expect(find.text('CHỌN TÊN CỦA BẠN'), findsOneWidget);
    expect(find.text('CHỌN NHÂN VẬT'), findsOneWidget);
    expect(find.text('BẮT ĐẦU CHƠI'), findsOneWidget);
  });

  testWidgets('onboarding supports English', (tester) async {
    await tester.pumpWidget(
      _app(FakeProfileRepository(), locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHOOSE YOUR NAME'), findsOneWidget);
    expect(find.text('CHOOSE YOUR CHARACTER'), findsOneWidget);
    expect(find.text('START PLAYING'), findsOneWidget);
  });

  testWidgets('successful onboarding submits trimmed values and opens Home', (
    tester,
  ) async {
    final profiles = FakeProfileRepository();
    await tester.pumpWidget(_app(profiles));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('username-field')), '  Dũng  ');
    await tester.tap(find.byKey(const Key('avatar-avatar_02')));
    final completeButton = find.byKey(const Key('complete-profile-button'));
    await tester.ensureVisible(completeButton);
    await tester.tap(completeButton);
    await tester.pumpAndSettle();

    expect(profiles.submittedUsername, 'Dũng');
    expect(profiles.submittedAvatarId, 'avatar_02');
    expect(find.byKey(HomeScreen.screenKey), findsOneWidget);
  });

  testWidgets('onboarding failure shows a friendly localized error', (
    tester,
  ) async {
    final profiles = FakeProfileRepository(
      completeError: const ProfileCreationAppError(),
    );
    await tester.pumpWidget(_app(profiles));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('username-field')), 'Dũng');
    final completeButton = find.byKey(const Key('complete-profile-button'));
    await tester.ensureVisible(completeButton);
    await tester.tap(completeButton);
    await tester.pumpAndSettle();

    expect(find.byKey(OnboardingScreen.screenKey), findsOneWidget);
    expect(find.byKey(const Key('onboarding-error')), findsOneWidget);
    expect(find.text('Không thể tạo hồ sơ. Vui lòng thử lại.'), findsOneWidget);
  });
}
