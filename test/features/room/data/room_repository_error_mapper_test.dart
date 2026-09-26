import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/features/room/data/room_repository_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final mappings = <String, Type>{
    'room_not_found': RoomNotFoundAppError,
    'room_full': RoomFullAppError,
    'already_in_another_room': AlreadyInAnotherRoomAppError,
    'room_closed': RoomClosedAppError,
    'room_in_game': RoomInGameAppError,
  };

  for (final entry in mappings.entries) {
    test('maps ${entry.key} to a typed domain error', () {
      final mapped = RoomRepositoryErrorMapper.map(
        PostgrestException(message: entry.key),
      );

      expect(mapped.runtimeType, entry.value);
    });
  }

  test('does not expose an unknown backend error', () {
    final mapped = RoomRepositoryErrorMapper.map(
      const PostgrestException(message: 'sensitive database detail'),
    );

    expect(mapped, isA<RoomOperationAppError>());
  });
}
