import 'package:ai_la_ke_gia_mao/app/app.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/core/router/app_router.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/home/presentation/home_screen.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/player_profile.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/game_history.dart';
import 'package:ai_la_ke_gia_mao/features/profile/presentation/onboarding_screen.dart';
import 'package:ai_la_ke_gia_mao/features/profile/presentation/profile_screen.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_snapshot.dart';
import 'package:ai_la_ke_gia_mao/features/game/presentation/role_reveal_screen.dart';
import 'package:ai_la_ke_gia_mao/features/game/presentation/clue_screen.dart';
import 'package:ai_la_ke_gia_mao/features/game/presentation/discussion_screen.dart';
import 'package:ai_la_ke_gia_mao/features/game/presentation/voting_screen.dart';
import 'package:ai_la_ke_gia_mao/features/game/presentation/vote_result_screen.dart';
import 'package:ai_la_ke_gia_mao/features/game/presentation/final_guess_screen.dart';
import 'package:ai_la_ke_gia_mao/features/game/presentation/game_result_screen.dart';
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
  ProfileRepository? profiles,
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
        profiles ?? FakeProfileRepository(profile: profile ?? sampleProfile),
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

  testWidgets('Home opens authoritative Profile with XP and empty history', (
    tester,
  ) async {
    final profile = PlayerProfile(
      id: sampleProfile.id,
      username: 'Tên người chơi rất dài',
      avatarId: 'avatar_01',
      coins: 987654,
      xp: 1850,
      level: 4,
      gamesPlayed: 4,
      gamesWon: 2,
      normalWins: 1,
      impostorWins: 1,
      correctVotes: 2,
      createdAt: sampleProfile.createdAt,
      updatedAt: sampleProfile.updatedAt,
    );
    await tester.pumpWidget(_testApp(profile: profile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile-shortcut')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.byKey(ProfileScreen.screenKey), findsOneWidget);
    expect(find.text('350 / 500 XP'), findsWidgets);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có ván hoàn thành.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Profile renders private history and edit dialog on small screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profiles = FakeProfileRepository(profile: sampleProfile)
        ..historyPage = GameHistoryPage(
          items: [
            GameHistoryItem(
              gameId: 'g1',
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
            ),
          ],
        );
      await tester.pumpWidget(_testApp(profiles: profiles));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('profile-shortcut')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hồ sơ'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('THẮNG'), findsOneWidget);
      expect(find.textContaining('+180 XP'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('edit-profile')));
      await tester.tap(find.byKey(const Key('edit-profile')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-username')), findsOneWidget);
      expect(find.byKey(const Key('save-profile')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.text('READY TO VOTE'), findsOneWidget);
  });

  testWidgets('server voting and result phases route authoritatively', (
    tester,
  ) async {
    final voting = VotingSnapshot(
      roundNumber: 1,
      endsAt: sampleGame.phaseEndsAt!,
      candidates: [
        ...sampleGame.participants,
        const GameParticipantSummary(
          playerId: '00000000-0000-4000-8000-000000000002',
          username: 'Vote Two',
          avatarId: 'avatar_02',
          roleAcknowledged: true,
          discussionReady: true,
        ),
      ],
      submittedVoteCount: 0,
      eligibleVoterCount: 1,
      currentUserHasVoted: false,
      results: const [],
      nextRoundRequired: false,
      eliminatedPlayerId: null,
      resolvedByRandomTieBreak: false,
    );
    GameSnapshot game(GameStatus status, VotingSnapshot value) => GameSnapshot(
      gameId: sampleGame.gameId,
      roomId: sampleGame.roomId,
      roundNumber: 1,
      status: status,
      phaseStartedAt: sampleGame.phaseStartedAt,
      phaseEndsAt: sampleGame.phaseEndsAt,
      revision: 10,
      participants: sampleGame.participants,
      serverNow: sampleGame.serverNow,
      turns: const [],
      voting: value,
    );
    await tester.pumpWidget(
      _testApp(room: sampleRoom, game: game(GameStatus.voting, voting)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(VotingScreen.screenKey), findsOneWidget);
    await tester.tap(find.text('Vote Two'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn muốn bỏ phiếu cho Vote Two?'), findsOneWidget);
    await tester.tap(find.text('HỦY'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-vote')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      _testApp(
        room: sampleRoom,
        game: game(
          GameStatus.voteResult,
          VotingSnapshot(
            roundNumber: 1,
            endsAt: sampleGame.phaseEndsAt!,
            candidates: sampleGame.participants,
            submittedVoteCount: 1,
            eligibleVoterCount: 1,
            currentUserHasVoted: true,
            results: const [
              VoteResultEntry(
                playerId: '00000000-0000-4000-8000-000000000001',
                voteCount: 1,
              ),
            ],
            nextRoundRequired: false,
            eliminatedPlayerId: '00000000-0000-4000-8000-000000000001',
            resolvedByRandomTieBreak: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(VoteResultScreen.screenKey), findsOneWidget);
  });

  testWidgets(
    'server final guess phase shows choices only to guessing player',
    (tester) async {
      final game = GameSnapshot(
        gameId: sampleGame.gameId,
        roomId: sampleGame.roomId,
        roundNumber: 1,
        status: GameStatus.finalGuess,
        phaseStartedAt: sampleGame.phaseStartedAt,
        phaseEndsAt: sampleGame.phaseEndsAt,
        revision: 11,
        participants: sampleGame.participants,
        serverNow: sampleGame.serverNow,
        turns: const [],
        finalGuess: FinalGuessSnapshot(
          guessingPlayerId: sampleProfile.id,
          choices: const [
            FinalGuessChoice(
              choiceId: 'opaque-choice',
              wordVi: 'Dưa hấu',
              wordEn: 'Watermelon',
            ),
          ],
          hasSubmitted: false,
          timedOut: false,
        ),
      );
      await tester.pumpWidget(_testApp(room: sampleRoom, game: game));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(FinalGuessScreen.screenKey), findsOneWidget);
      expect(find.text('Dưa hấu'), findsOneWidget);
      await tester.tap(find.text('Dưa hấu'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn chắc chắn chọn Dưa hấu?'), findsOneWidget);
    },
  );

  testWidgets('server result phase renders authoritative winner and reward', (
    tester,
  ) async {
    final game = GameSnapshot(
      gameId: sampleGame.gameId,
      roomId: sampleGame.roomId,
      roundNumber: 1,
      status: GameStatus.result,
      phaseStartedAt: sampleGame.phaseStartedAt,
      phaseEndsAt: null,
      revision: 12,
      participants: [
        GameParticipantSummary(
          playerId: sampleProfile.id,
          username: sampleProfile.username,
          avatarId: sampleProfile.avatarId,
          roleAcknowledged: true,
          discussionReady: true,
          role: 'normal',
        ),
      ],
      serverNow: sampleGame.serverNow,
      turns: const [],
      result: GameResultSnapshot(
        winnerTeam: WinnerTeam.normal,
        reason: GameResultReason.impostorFinalGuessWrong,
        keywordVi: 'Dưa hấu',
        keywordEn: 'Watermelon',
        eliminatedPlayerId: sampleProfile.id,
        finishedAt: sampleGame.phaseStartedAt,
        reward: const RewardSummary(
          xpGained: 180,
          coinsGained: 20,
          newXp: 180,
          newCoins: 20,
          newLevel: 1,
        ),
      ),
    );
    await tester.pumpWidget(_testApp(room: sampleRoom, game: game));
    await tester.pumpAndSettle();
    expect(find.byKey(GameResultScreen.screenKey), findsOneWidget);
    expect(find.text('NGƯỜI THƯỜNG CHIẾN THẮNG!'), findsOneWidget);
    expect(find.text('+180 XP'), findsOneWidget);
    expect(find.byKey(const Key('play-again')), findsOneWidget);
  });
}
