import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/recovery/recovery_controller.dart';
import '../../auth/application/app_session_controller.dart';
import '../../auth/application/app_session_state.dart';
import '../domain/room_realtime.dart';
import '../domain/room_repository.dart';

class RoomRealtimeState {
  const RoomRealtimeState({
    this.connection = RoomConnectionState.connecting,
    this.onlinePlayerIds = const {},
  });

  final RoomConnectionState connection;
  final Set<String> onlinePlayerIds;

  RoomRealtimeState copyWith({
    RoomConnectionState? connection,
    Set<String>? onlinePlayerIds,
  }) => RoomRealtimeState(
    connection: connection ?? this.connection,
    onlinePlayerIds: onlinePlayerIds ?? this.onlinePlayerIds,
  );
}

class RoomRealtimeController extends Notifier<RoomRealtimeState> {
  RoomRealtimeSession? _session;
  StreamSubscription<RoomRealtimeEvent>? _events;
  Timer? _debounce;
  String? _roomId;

  @override
  RoomRealtimeState build() {
    ref.onDispose(() {
      unawaited(stop());
    });
    return const RoomRealtimeState();
  }

  Future<void> start(String roomId) async {
    if (_roomId == roomId && _session != null) return;
    await stop();
    _roomId = roomId;
    state = const RoomRealtimeState();
    final repository = ref.read(roomRepositoryProvider);
    if (repository == null) return;
    try {
      _session = await repository.connectRealtime(roomId);
      _events = _session!.events.listen(_onEvent);
    } catch (_) {
      state = state.copyWith(connection: RoomConnectionState.reconnecting);
    }
  }

  void _onEvent(RoomRealtimeEvent event) {
    switch (event) {
      case RoomInvalidated():
        _debounce?.cancel();
        _debounce = Timer(
          const Duration(milliseconds: 120),
          () => unawaited(
            ref
                .read(recoveryControllerProvider.notifier)
                .recover(RecoveryReason.realtime),
          ),
        );
      case RoomPresenceChanged(:final onlinePlayerIds):
        final current = ref.read(appSessionControllerProvider);
        final members = current is AppSessionReady
            ? current.room?.members.map((member) => member.playerId).toSet() ??
                  const <String>{}
            : const <String>{};
        state = state.copyWith(
          onlinePlayerIds: onlinePlayerIds.intersection(members),
        );
      case RoomConnectionChanged(:final state):
        final wasConnected =
            this.state.connection == RoomConnectionState.connected;
        this.state = this.state.copyWith(connection: state);
        if (state == RoomConnectionState.connected && !wasConnected) {
          unawaited(
            ref
                .read(recoveryControllerProvider.notifier)
                .recover(RecoveryReason.realtime),
          );
        }
    }
  }

  Future<void> refresh() async {
    await ref
        .read(recoveryControllerProvider.notifier)
        .recover(RecoveryReason.manual);
  }

  Future<void> ensureSubscription(String roomId) async {
    if (_roomId == roomId && _session != null) return;
    await start(roomId);
  }

  Future<void> stop() async {
    _debounce?.cancel();
    _debounce = null;
    final events = _events;
    _events = null;
    final session = _session;
    _session = null;
    _roomId = null;
    await events?.cancel();
    await session?.dispose();
  }
}

final roomRealtimeControllerProvider =
    NotifierProvider<RoomRealtimeController, RoomRealtimeState>(
      RoomRealtimeController.new,
    );
