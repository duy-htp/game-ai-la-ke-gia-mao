enum RoomConnectionState { connecting, connected, reconnecting }

sealed class RoomRealtimeEvent {
  const RoomRealtimeEvent();
}

final class RoomInvalidated extends RoomRealtimeEvent {
  const RoomInvalidated();
}

final class RoomPresenceChanged extends RoomRealtimeEvent {
  const RoomPresenceChanged(this.onlinePlayerIds);
  final Set<String> onlinePlayerIds;
}

final class RoomConnectionChanged extends RoomRealtimeEvent {
  const RoomConnectionChanged(this.state);
  final RoomConnectionState state;
}

abstract interface class RoomRealtimeSession {
  Stream<RoomRealtimeEvent> get events;
  Future<void> dispose();
}
