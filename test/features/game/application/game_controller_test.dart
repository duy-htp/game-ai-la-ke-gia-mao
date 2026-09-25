import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_controller.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_state.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/application/game_controller.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

ProviderContainer makeContainer(FakeGameRepository games) => ProviderContainer(
  overrides: [
    appConfigProvider.overrideWithValue(
      const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: 'http://localhost',
        supabaseAnonKey: 'key',
      ),
    ),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    profileRepositoryProvider.overrideWithValue(
      FakeProfileRepository(profile: sampleProfile),
    ),
    roomRepositoryProvider.overrideWithValue(
      FakeRoomRepository(currentRoom: sampleRoom),
    ),
    gameRepositoryProvider.overrideWithValue(games),
  ],
);
void main() {
  test('start success stores authoritative public game', () async {
    final games = FakeGameRepository();
    final container = makeContainer(games);
    addTearDown(container.dispose);
    await container.read(appSessionControllerProvider.notifier).initialize();
    await container.read(gameControllerProvider.notifier).startGame();
    expect(games.startCalls, 1);
    expect(
      (container.read(appSessionControllerProvider) as AppSessionReady).game,
      sampleGame,
    );
  });
  test('start failure exposes safe typed state', () async {
    final games = FakeGameRepository(error: const GameOperationAppError());
    final container = makeContainer(games);
    addTearDown(container.dispose);
    await container.read(appSessionControllerProvider.notifier).initialize();
    await container.read(gameControllerProvider.notifier).startGame();
    expect(container.read(gameControllerProvider), isA<GameActionError>());
  });
}
