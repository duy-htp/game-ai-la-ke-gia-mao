import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/features/room/domain/room_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes whitespace and lowercase input', () {
    expect(RoomCode.parse(' ab2k9p ').value, 'AB2K9P');
  });

  test('accepts only exactly six characters from the safe alphabet', () {
    for (final valid in ['234567', 'ABCDEF', 'Z9K2NP']) {
      expect(RoomCode.parse(valid).value, valid);
    }
    for (final invalid in ['ABC12', 'ABC1234', 'O0I1L!', 'ABC 23', '']) {
      expect(
        () => RoomCode.parse(invalid),
        throwsA(isA<InvalidRoomCodeAppError>()),
      );
    }
  });
}
