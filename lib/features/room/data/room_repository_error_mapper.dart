import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';

abstract final class RoomRepositoryErrorMapper {
  static AppError map(Object error) {
    if (error is AppError) return error;
    if (error is SocketException) return const NetworkAppError();
    if (error is PostgrestException) {
      return switch (error.message) {
        'invalid_room_code' => const InvalidRoomCodeAppError(),
        'room_not_found' => const RoomNotFoundAppError(),
        'room_closed' => const RoomClosedAppError(),
        'room_full' => const RoomFullAppError(),
        'already_in_another_room' => const AlreadyInAnotherRoomAppError(),
        'unsupported_game_type' => const UnsupportedGameTypeAppError(),
        'invalid_max_players' => const InvalidMaxPlayersAppError(),
        'profile_required' => const ProfileRequiredAppError(),
        'not_room_member' => const NotRoomMemberAppError(),
        _ => const RoomOperationAppError(),
      };
    }
    return const RoomOperationAppError();
  }
}
