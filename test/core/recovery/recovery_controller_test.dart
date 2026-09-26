import 'dart:async';

import 'package:ai_la_ke_gia_mao/core/config/app_config.dart';
import 'package:ai_la_ke_gia_mao/core/config/app_environment.dart';
import 'package:ai_la_ke_gia_mao/core/recovery/recovery_controller.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_controller.dart';
import 'package:ai_la_ke_gia_mao/features/auth/application/app_session_state.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_snapshot.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_status.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_snapshot.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

class _ControlledRoomRepository extends FakeRoomRepository {
  _ControlledRoomRepository({required super.currentRoom});

  Completer<void>? gate;
  Completer<void>? entered;
  RoomSnapshot? delayedResult;

  @override
  Future<RoomSnapshot?> loadCurrentRoom() async {
    loadCalls++;
    final wait = gate;
    if (wait != null) {
      entered?.complete();
      await wait.future;
      gate = null;
      return delayedResult;
    }
    return currentRoom;
  }
}

RoomSnapshot _room(int revision) => RoomSnapshot(
  roomId: sampleRoom.roomId,
  code: sampleRoom.code,
  gameType: sampleRoom.gameType,
  status: sampleRoom.status,
  maxPlayers: sampleRoom.maxPlayers,
  hostId: sampleRoom.hostId,
  members: sampleRoom.members,
  revision: revision,
);

RoomSnapshot _inGameRoom() => RoomSnapshot(
  roomId: sampleRoom.roomId,
  code: sampleRoom.code,
  gameType: sampleRoom.gameType,
  status: RoomStatus.inGame,
  maxPlayers: sampleRoom.maxPlayers,
  hostId: sampleRoom.hostId,
  members: sampleRoom.members,
  revision: 2,
);

GameSnapshot _game({required DateTime endsAt, required int revision}) =>
    GameSnapshot(
      gameId: sampleGame.gameId,
      roomId: sampleGame.roomId,
      roundNumber: 1,
      status: GameStatus.clue,
      phaseStartedAt: endsAt.subtract(const Duration(seconds: 30)),
      phaseEndsAt: endsAt,
      revision: revision,
      participants: sampleGame.participants,
      serverNow: DateTime.utc(2026, 9, 26),
      turns: const [],
    );

class _AdvancingGameRepository extends FakeGameRepository {
  _AdvancingGameRepository({required super.currentGame, required this.after});
  final GameSnapshot after;

  @override
  Future<GameSnapshot> advanceIfDue() async {
    advanceCalls++;
    return currentGame = after;
  }
}

ProviderContainer _container(
  _ControlledRoomRepository rooms, {
  FakeGameRepository? games,
}) => ProviderContainer(
  overrides: [
    appConfigProvider.overrideWithValue(
      const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: 'http://127.0.0.1:54321',
        supabaseAnonKey: 'test',
      ),
    ),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    profileRepositoryProvider.overrideWithValue(
      FakeProfileRepository(profile: sampleProfile),
    ),
    roomRepositoryProvider.overrideWithValue(rooms),
    gameRepositoryProvider.overrideWithValue(games ?? FakeGameRepository()),
  ],
);

void main() {
  test('20 recovery triggers coalesce to one bounded follow-up pass', () async {
    final rooms = _ControlledRoomRepository(currentRoom: sampleRoom);
    final container = _container(rooms);
    addTearDown(container.dispose);
    await container.read(appSessionControllerProvider.notifier).initialize();
    rooms
      ..gate = Completer<void>()
      ..entered = Completer<void>()
      ..delayedResult = _room(2);
    final controller = container.read(recoveryControllerProvider.notifier);
    final first = controller.recover(RecoveryReason.manual);
    await rooms.entered!.future;
    for (var i = 0; i < 20; i++) {
      unawaited(controller.recover(RecoveryReason.realtime));
    }
    rooms.gate!.complete();
    await first;

    expect(
      rooms.loadCalls,
      3,
      reason: 'initialize + stale pass + one follow-up',
    );
    expect(container.read(recoveryControllerProvider).passCount, 1);
  });

  test(
    'superseded late response cannot overwrite newer room revision',
    () async {
      final rooms = _ControlledRoomRepository(currentRoom: sampleRoom);
      final container = _container(rooms);
      addTearDown(container.dispose);
      await container.read(appSessionControllerProvider.notifier).initialize();
      rooms
        ..gate = Completer<void>()
        ..entered = Completer<void>()
        ..delayedResult = _room(10);
      final controller = container.read(recoveryControllerProvider.notifier);
      final first = controller.recover(RecoveryReason.manual);
      await rooms.entered!.future;
      rooms.currentRoom = _room(11);
      unawaited(controller.recover(RecoveryReason.realtime));
      rooms.gate!.complete();
      await first;

      final session =
          container.read(appSessionControllerProvider) as AppSessionReady;
      expect(session.room!.revision, 11);
    },
  );

  test('expired deadline advances and refetches to a stable phase', () async {
    final now = DateTime.utc(2026, 9, 26);
    final due = _game(
      endsAt: now.subtract(const Duration(seconds: 1)),
      revision: 4,
    );
    final stable = _game(
      endsAt: now.add(const Duration(seconds: 30)),
      revision: 5,
    );
    final rooms = _ControlledRoomRepository(currentRoom: _inGameRoom());
    final games = _AdvancingGameRepository(currentGame: due, after: stable);
    final container = _container(rooms, games: games);
    addTearDown(container.dispose);
    await container.read(appSessionControllerProvider.notifier).initialize();

    await container
        .read(recoveryControllerProvider.notifier)
        .recover(RecoveryReason.resumed);

    final session =
        container.read(appSessionControllerProvider) as AppSessionReady;
    expect(games.advanceCalls, 1);
    expect(session.game!.revision, 5);
  });
}
