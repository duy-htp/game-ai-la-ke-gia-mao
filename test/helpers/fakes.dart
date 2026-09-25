import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_identity.dart';
import 'package:ai_la_ke_gia_mao/features/auth/domain/auth_repository.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/player_profile.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/game_type.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_code.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_repository.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_snapshot.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_status.dart';

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
  });

  RoomSnapshot? currentRoom;
  final Object? loadError;
  Object? createError;
  Object? joinError;
  Object? leaveError;
  int loadCalls = 0;
  int createCalls = 0;
  int joinCalls = 0;
  int leaveCalls = 0;
  int? submittedMaxPlayers;
  String? submittedRequestId;
  RoomCode? submittedCode;

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
    return currentRoom ?? sampleRoom;
  }

  @override
  Future<RoomSnapshot> joinRoom(RoomCode code) async {
    joinCalls += 1;
    submittedCode = code;
    if (joinError case final error?) throw error;
    return currentRoom ?? sampleRoom;
  }

  @override
  Future<void> leaveRoom() async {
    leaveCalls += 1;
    if (leaveError case final error?) throw error;
    currentRoom = null;
  }
}
