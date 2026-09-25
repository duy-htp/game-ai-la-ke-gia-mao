import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/profile_input_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trims username while preserving Vietnamese Unicode', () {
    final input = ProfileInputValidator.validate(
      username: '  Dũng  ',
      avatarId: 'avatar_01',
    );

    expect(input.username, 'Dũng');
  });

  test('accepts a Vietnamese display name', () {
    final input = ProfileInputValidator.validate(
      username: 'Nguyễn An',
      avatarId: 'avatar_12',
    );

    expect(input.username, 'Nguyễn An');
  });

  test('rejects blank, short, long, and control-character usernames', () {
    for (final username in ['', ' ', 'A', '123456789012345678901', 'An\nNg']) {
      expect(
        () => ProfileInputValidator.validate(
          username: username,
          avatarId: 'avatar_01',
        ),
        throwsA(isA<InvalidUsernameAppError>()),
      );
    }
  });

  test('rejects an avatar outside the predefined catalog', () {
    expect(
      () => ProfileInputValidator.validate(
        username: 'Dũng',
        avatarId: 'https://example.test/avatar.png',
      ),
      throwsA(isA<InvalidAvatarAppError>()),
    );
  });
}
