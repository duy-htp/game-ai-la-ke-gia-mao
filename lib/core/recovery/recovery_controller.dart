import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/app_session_controller.dart';
import '../../features/auth/application/app_session_state.dart';
import '../../features/game/domain/game_repository.dart';
import '../../features/game/domain/game_snapshot.dart';
import '../../features/room/application/room_realtime_controller.dart';
import '../../features/room/domain/room_repository.dart';
import '../../features/room/domain/room_status.dart';
import '../../features/profile/domain/profile_repository.dart';

enum RecoveryStatus { idle, recovering, failed }

class RecoveryState {
  const RecoveryState({this.status = RecoveryStatus.idle, this.passCount = 0});
  final RecoveryStatus status;
  final int passCount;
}

enum RecoveryReason { startup, resumed, realtime, manual, uncertainMutation }

class RecoveryController extends Notifier<RecoveryState> {
  static const maxDueAdvances = 16;
  Future<void>? _inFlight;
  bool _followUpRequested = false;
  int _generation = 0;

  @override
  RecoveryState build() {
    ref.onDispose(() => _generation++);
    return const RecoveryState();
  }

  Future<void> activate() async {
    final session = ref.read(appSessionControllerProvider);
    if (session is AppSessionReady &&
        session.room?.status == RoomStatus.inGame) {
      await recover(RecoveryReason.startup);
    }
    await syncSubscription();
  }

  Future<void> syncSubscription() async {
    final session = ref.read(appSessionControllerProvider);
    if (session is AppSessionReady && session.room != null) {
      await ref
          .read(roomRealtimeControllerProvider.notifier)
          .ensureSubscription(session.room!.roomId);
    } else {
      await ref.read(roomRealtimeControllerProvider.notifier).stop();
    }
  }

  Future<void> recover(RecoveryReason reason) {
    if (_inFlight != null) {
      _followUpRequested = true;
      _generation++;
    }
    return _inFlight ??= _run(reason).whenComplete(() => _inFlight = null);
  }

  Future<void> _run(RecoveryReason reason) async {
    do {
      _followUpRequested = false;
      final generation = ++_generation;
      state = RecoveryState(
        status: RecoveryStatus.recovering,
        passCount: state.passCount,
      );
      try {
        await _recoverOnce(generation);
        if (generation != _generation) continue;
        state = RecoveryState(passCount: state.passCount + 1);
      } catch (_) {
        if (generation == _generation) {
          state = RecoveryState(
            status: RecoveryStatus.failed,
            passCount: state.passCount,
          );
        }
      }
    } while (_followUpRequested);
  }

  Future<void> _recoverOnce(int generation) async {
    final current = ref.read(appSessionControllerProvider);
    if (current is! AppSessionReady) return;
    final rooms = ref.read(roomRepositoryProvider);
    final games = ref.read(gameRepositoryProvider);
    final profiles = ref.read(profileRepositoryProvider);
    if (rooms == null || games == null || profiles == null) return;
    final profile = await profiles.fetchOwnProfile();
    if (generation != _generation || profile == null) return;
    final room = await rooms.loadCurrentRoom();
    if (generation != _generation) return;
    GameSnapshot? game;
    if (room?.status == RoomStatus.inGame) {
      game = await games.loadCurrentGame();
      if (generation != _generation) return;
      for (var i = 0; i < maxDueAdvances && _isDue(game); i++) {
        game = await games.advanceIfDue();
        if (generation != _generation) return;
        game = await games.loadCurrentGame() ?? game;
        if (generation != _generation) return;
      }
    }
    ref.read(appSessionControllerProvider.notifier).setProfile(profile);
    ref
        .read(appSessionControllerProvider.notifier)
        .applyRecovered(room: room, game: game);
    if (room == null) {
      await ref.read(roomRealtimeControllerProvider.notifier).stop();
    } else {
      await ref
          .read(roomRealtimeControllerProvider.notifier)
          .ensureSubscription(room.roomId);
    }
  }

  bool _isDue(GameSnapshot? game) =>
      game?.phaseEndsAt != null && !game!.phaseEndsAt!.isAfter(game.serverNow);
}

final recoveryControllerProvider =
    NotifierProvider<RecoveryController, RecoveryState>(RecoveryController.new);
