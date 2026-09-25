import 'package:ai_la_ke_gia_mao/features/room/domain/room_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the safe host/member projection', () {
    final room = RoomSnapshot.fromJson({
      'room_id': 'room-id',
      'code': 'AB2K9P',
      'game_type': 'impostor',
      'status': 'waiting',
      'max_players': 6,
      'host_id': 'player-id',
      'members': [
        {
          'player_id': 'player-id',
          'username': 'Dũng',
          'avatar_id': 'avatar_01',
          'seat': 1,
          'is_host': true,
          'joined_at': '2026-09-25T00:00:00Z',
        },
      ],
    });

    expect(room.members.single.username, 'Dũng');
    expect(room.members.single.isHost, isTrue);
    expect(room.members.single.seat, 1);
  });
}
