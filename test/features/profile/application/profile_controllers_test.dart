import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_controller.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_state.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/application/game_history_controller.dart';
import 'package:ai_la_ke_gia_mao/features/profile/application/profile_controller.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/game_history.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/player_profile.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

ProviderContainer containerFor(ProfileRepository profiles) {
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
      profileRepositoryProvider.overrideWithValue(profiles),
      roomRepositoryProvider.overrideWithValue(FakeRoomRepository()),
      gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
    ],
  );
}

void main() {
  test('save normalizes input and installs authoritative response', () async {
    final updated = copyProfile(sampleProfile, username: 'Tên mới');
    final repository = _ProfileRepository(profile: sampleProfile)
      ..updatedProfile = updated;
    final container = containerFor(repository);
    addTearDown(container.dispose);
    await container.read(appSessionControllerProvider.notifier).initialize();

    final saved = await container
        .read(profileControllerProvider.notifier)
        .save('  Tên   mới  ', 'avatar_01');

    expect(saved, isTrue);
    expect(repository.submittedUsername, 'Tên mới');
    expect(
      (container.read(appSessionControllerProvider) as AppSessionReady).profile,
      updated,
    );
    expect(container.read(profileControllerProvider), isA<ProfileIdle>());
  });

  test('save reconciles an unknown network outcome by refetching', () async {
    final updated = copyProfile(sampleProfile, username: 'Tên mới');
    final repository = _ProfileRepository(profile: sampleProfile)
      ..updatedProfile = updated
      ..updateError = const NetworkAppError()
      ..profileAfterFailedUpdate = updated;
    final container = containerFor(repository);
    addTearDown(container.dispose);
    await container.read(appSessionControllerProvider.notifier).initialize();

    final saved = await container
        .read(profileControllerProvider.notifier)
        .save('Tên mới', 'avatar_01');

    expect(saved, isTrue);
    expect(repository.fetchCalls, 2);
    expect(container.read(profileControllerProvider), isA<ProfileIdle>());
  });

  test('history refresh and pagination merge unique games', () async {
    final repository = _ProfileRepository(profile: sampleProfile)
      ..pages.addAll([
        _page('g2', hasMore: true),
        GameHistoryPage(items: [_item('g2'), _item('g1')]),
      ]);
    final container = containerFor(repository);
    addTearDown(container.dispose);

    await container.read(gameHistoryControllerProvider.notifier).refresh();
    await container.read(gameHistoryControllerProvider.notifier).loadMore();

    final state = container.read(gameHistoryControllerProvider);
    expect(state.items.map((item) => item.gameId), ['g2', 'g1']);
    expect(state.hasMore, isFalse);
  });

  test('history keeps existing items when pagination fails', () async {
    final repository = _ProfileRepository(profile: sampleProfile)
      ..pages.add(_page('g2', hasMore: true));
    final container = containerFor(repository);
    addTearDown(container.dispose);
    await container.read(gameHistoryControllerProvider.notifier).refresh();
    repository.historyError = const NetworkAppError();

    await container.read(gameHistoryControllerProvider.notifier).loadMore();

    final state = container.read(gameHistoryControllerProvider);
    expect(state.items.single.gameId, 'g2');
    expect(state.error, isA<NetworkAppError>());
  });
}

PlayerProfile copyProfile(PlayerProfile source, {required String username}) =>
    PlayerProfile(
      id: source.id,
      username: username,
      avatarId: source.avatarId,
      coins: source.coins,
      xp: source.xp,
      level: source.level,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt.add(const Duration(seconds: 1)),
    );

GameHistoryPage _page(String id, {required bool hasMore}) => GameHistoryPage(
  items: [_item(id)],
  nextFinishedAt: hasMore ? DateTime.utc(2026, 9, 26) : null,
  nextGameId: hasMore ? id : null,
);

GameHistoryItem _item(String id) => GameHistoryItem(
  gameId: id,
  roundNumber: 1,
  finishedAt: DateTime.utc(2026, 9, 27),
  winnerTeam: 'normal',
  resultReason: 'impostor_final_guess_wrong',
  callerRole: 'normal',
  didWin: true,
  keywordVi: 'Dưa hấu',
  keywordEn: 'Watermelon',
  categoryVi: 'Đồ ăn',
  categoryEn: 'Food',
  xpGained: 180,
  coinsGained: 20,
  playerCount: 3,
);

class _ProfileRepository implements ProfileRepository {
  _ProfileRepository({required this.profile});
  PlayerProfile? profile;
  PlayerProfile? updatedProfile;
  PlayerProfile? profileAfterFailedUpdate;
  AppError? updateError;
  AppError? historyError;
  final List<GameHistoryPage> pages = [];
  int fetchCalls = 0;
  String? submittedUsername;

  @override
  Future<PlayerProfile?> fetchOwnProfile() async {
    fetchCalls++;
    if (fetchCalls > 1 && profileAfterFailedUpdate != null) {
      return profileAfterFailedUpdate;
    }
    return profile;
  }

  @override
  Future<PlayerProfile> updateProfile({
    required String username,
    required String avatarId,
  }) async {
    submittedUsername = username;
    if (updateError case final error?) throw error;
    return updatedProfile!;
  }

  @override
  Future<GameHistoryPage> fetchGameHistory({
    int limit = 20,
    DateTime? beforeFinishedAt,
    String? beforeGameId,
  }) async {
    if (historyError case final error?) throw error;
    return pages.removeAt(0);
  }

  @override
  Future<PlayerProfile> completeProfile({
    required String username,
    required String avatarId,
  }) async => profile!;
}
