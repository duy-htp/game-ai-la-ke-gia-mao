import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_snapshot.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/game_status.dart';
import 'package:ai_la_ke_gia_mao/features/game/domain/player_game_secret.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses public snapshot without secret fields', () {
    final game = GameSnapshot.fromJson({
      'game_id': 'g1',
      'room_id': 'r1',
      'round_number': 1,
      'status': 'role_reveal',
      'phase_started_at': '2026-09-25T00:00:00Z',
      'phase_ends_at': '2026-09-25T00:00:15Z',
      'revision': 1,
      'participants': [
        {'player_id': 'p1', 'username': 'An', 'avatar_id': 'avatar_01'},
      ],
    });
    expect(game.status, GameStatus.roleReveal);
    expect(game.participants.single.username, 'An');
  });
  test('normal secret requires both localized names', () {
    final secret = PlayerGameSecret.fromJson({
      'role': 'normal',
      'word_vi': 'Dưa hấu',
      'word_en': 'Watermelon',
    });
    expect(secret.role, PlayerRole.normal);
    expect(secret.wordEn, 'Watermelon');
  });
  test('parses public acknowledgement and clue turn history', () {
    final game = GameSnapshot.fromJson({
      'game_id': 'g1',
      'room_id': 'r1',
      'round_number': 1,
      'status': 'clue',
      'phase_started_at': '2026-09-25T00:00:00Z',
      'phase_ends_at': '2026-09-25T00:00:30Z',
      'server_now': '2026-09-25T00:00:10Z',
      'revision': 4,
      'participants': [
        {
          'player_id': 'p1',
          'username': 'An',
          'avatar_id': 'avatar_01',
          'role_acknowledged': true,
        },
      ],
      'turns': [
        {
          'turn_id': 1,
          'turn_index': 1,
          'player_id': 'p1',
          'status': 'submitted',
          'started_at': '2026-09-25T00:00:00Z',
          'ends_at': '2026-09-25T00:00:30Z',
          'completed_at': '2026-09-25T00:00:08Z',
          'clue_text': 'Mùa hè',
        },
      ],
    });
    expect(game.status, GameStatus.clue);
    expect(game.participants.single.roleAcknowledged, isTrue);
    expect(game.turns.single.clueText, 'Mùa hè');
    expect(game.activeTurn, isNull);
  });
  test('impostor secret rejects any keyword leakage', () {
    expect(
      () => PlayerGameSecret.fromJson({
        'role': 'impostor',
        'word_vi': 'x',
        'word_en': null,
      }),
      throwsA(isA<SecretUnavailableAppError>()),
    );
    final secret = PlayerGameSecret.fromJson({
      'role': 'impostor',
      'word_vi': null,
      'word_en': null,
    });
    expect(secret.role, PlayerRole.impostor);
  });
}
