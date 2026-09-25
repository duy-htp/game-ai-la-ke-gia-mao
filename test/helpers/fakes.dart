import 'dart:async';

import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_identity.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/player_profile.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/game_type.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_code.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_snapshot.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_status.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_repository.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_snapshot.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_status.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/player_game_secret.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/lobby_settings.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_realtime.dart';

final sampleProfile = PlayerProfile(
  id: '00000000-0000-4000-8000-000000000001',
  username: 'Dũng',
  avatarId: 'avatar_01',
  coins: 0,
  xp: 0,
  level: 1,
  createdAt: DateTime.utc(2026, 9, 24),
  updatedAt: DateTime.utc(2026, 9, 24),
);

final sampleRoom = RoomSnapshot(
  roomId: '10000000-0000-4000-8000-000000000001',
  code: RoomCode.parse('AB2K9P'),
  gameType: GameType.impostor,
  status: RoomStatus.waiting,
  maxPlayers: 6,
  hostId: sampleProfile.id,
  members: [
    RoomMember(
      playerId: sampleProfile.id,
      username: sampleProfile.username,
      avatarId: sampleProfile.avatarId,
      seat: 1,
      isHost: true,
      joinedAt: DateTime.utc(2026, 9, 25),
    ),
  ],
);

final sampleGame = GameSnapshot(
  gameId: '30000000-0000-4000-8000-000000000001',
  roomId: sampleRoom.roomId,
  roundNumber: 1,
  status: GameStatus.roleReveal,
  phaseStartedAt: DateTime.utc(2026, 9, 25),
  phaseEndsAt: DateTime.utc(2026, 9, 25, 0, 0, 15),
  revision: 1,
  serverNow: DateTime.utc(2026, 9, 25),
  turns: const [],
  participants: [
    GameParticipantSummary(
      playerId: sampleProfile.id,
      username: sampleProfile.username,
      avatarId: sampleProfile.avatarId,
      roleAcknowledged: false,
    ),
  ],
);

class FakeGameRepository implements GameRepository {
  FakeGameRepository({
    this.currentGame,
    this.secret = const PlayerGameSecret(
      role: PlayerRole.normal,
      wordVi: 'Dưa hấu',
      wordEn: 'Watermelon',
    ),
    this.error,
  });
  GameSnapshot? currentGame;
  final PlayerGameSecret secret;
  final Object? error;
  int startCalls = 0;
  int loadCalls = 0;
  int secretCalls = 0;
  int acknowledgeCalls = 0;
  int advanceCalls = 0;
  int submitCalls = 0;
  String? submittedText;
  @override
  Future<GameSnapshot> startGame(String requestId) async {
    startCalls++;
    if (error case final value?) throw value;
    return currentGame ??= sampleGame;
  }

  @override
  Future<GameSnapshot?> loadCurrentGame() async {
    loadCalls++;
    if (error case final value?) throw value;
    return currentGame;
  }

  @override
  Future<PlayerGameSecret> loadMySecret() async {
    secretCalls++;
    if (error case final value?) throw value;
    return secret;
  }

  @override
  Future<GameSnapshot> acknowledgeRole() async {
    acknowledgeCalls++;
    if (error case final value?) throw value;
    return currentGame ?? sampleGame;
  }

  @override
  Future<GameSnapshot> advanceIfDue() async {
    advanceCalls++;
    if (error case final value?) throw value;
    return currentGame ?? sampleGame;
  }

  @override
  Future<GameSnapshot> submitClue(String text) async {
    submitCalls++;
    submittedText = text;
    if (error case final value?) throw value;
    return currentGame ?? sampleGame;
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.error});

  final Object? error;
  int calls = 0;

  @override
  Future<AuthIdentity> ensureAuthenticated() async {
    calls += 1;
    if (error case final error?) throw error;
    return const AuthIdentity(id: '00000000-0000-4000-8000-000000000001');
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile, this.fetchError, this.completeError});

  PlayerProfile? profile;
  final Object? fetchError;
  final Object? completeError;
  int fetchCalls = 0;
  int completeCalls = 0;
  String? submittedUsername;
  String? submittedAvatarId;

  @override
  Future<PlayerProfile?> fetchOwnProfile() async {
    fetchCalls += 1;
    if (fetchError case final error?) throw error;
    return profile;
  }

  @override
  Future<PlayerProfile> completeProfile({
    required String username,
    required String avatarId,
  }) async {
    completeCalls += 1;
    submittedUsername = username;
    submittedAvatarId = avatarId;
    if (completeError case final error?) throw error;
    return profile ?? sampleProfile;
  }
}

class FakeRoomRepository implements RoomRepository {
  FakeRoomRepository({
    this.currentRoom,
    this.loadError,
    this.createError,
    this.joinError,
    this.leaveError,
    this.readyError,
    this.settingsError,
  });

  RoomSnapshot? currentRoom;
  final Object? loadError;
  Object? createError;
  Object? joinError;
  Object? leaveError;
  Object? readyError;
  Object? settingsError;
  int loadCalls = 0;
  int createCalls = 0;
  int joinCalls = 0;
  int leaveCalls = 0;
  int readyCalls = 0;
  int settingsCalls = 0;
  int? submittedMaxPlayers;
  String? submittedRequestId;
  RoomCode? submittedCode;
  bool? submittedReady;
  LobbySettings? submittedSettings;
  FakeRoomRealtimeSession? lastRealtimeSession;

  @override
  Future<RoomSnapshot?> loadCurrentRoom() async {
    loadCalls += 1;
    if (loadError case final error?) throw error;
    return currentRoom;
  }

  @override
  Future<RoomSnapshot> createRoom({
    required GameType gameType,
    required int maxPlayers,
    required String requestId,
  }) async {
    createCalls += 1;
    submittedMaxPlayers = maxPlayers;
    submittedRequestId = requestId;
    if (createError case final error?) throw error;
    return currentRoom ??= sampleRoom;
  }

  @override
  Future<RoomSnapshot> joinRoom(RoomCode code) async {
    joinCalls += 1;
    submittedCode = code;
    if (joinError case final error?) throw error;
    return currentRoom ??= sampleRoom;
  }

  @override
  Future<void> leaveRoom() async {
    leaveCalls += 1;
    if (leaveError case final error?) throw error;
    currentRoom = null;
  }

  @override
  Future<RoomSnapshot> setReady(bool isReady) async {
    readyCalls += 1;
    submittedReady = isReady;
    if (readyError case final error?) throw error;
    return currentRoom ?? sampleRoom;
  }

  @override
  Future<RoomSnapshot> updateSettings(LobbySettings settings) async {
    settingsCalls += 1;
    submittedSettings = settings;
    if (settingsError case final error?) throw error;
    return currentRoom ?? sampleRoom;
  }

  @override
  Future<List<GameCategory>> loadCategories() async => const [];

  @override
  Future<RoomRealtimeSession> connectRealtime(String roomId) async =>
      lastRealtimeSession = FakeRoomRealtimeSession();
}

class FakeRoomRealtimeSession implements RoomRealtimeSession {
  final controller = StreamController<RoomRealtimeEvent>.broadcast();

  @override
  Stream<RoomRealtimeEvent> get events => controller.stream;

  @override
  Future<void> dispose() => controller.close();
}
