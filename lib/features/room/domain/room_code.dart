import '../../../core/errors/app_error.dart';

class RoomCode {
  const RoomCode._(this.value);

  static final _validPattern = RegExp(
    r'^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$',
  );

  factory RoomCode.parse(String input) {
    final normalized = input.trim().toUpperCase();
    if (!_validPattern.hasMatch(normalized)) {
      throw const InvalidRoomCodeAppError();
    }
    return RoomCode._(normalized);
  }

  final String value;

  @override
  String toString() => value;
}
