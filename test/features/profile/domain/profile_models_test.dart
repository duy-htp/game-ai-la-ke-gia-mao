import 'package:ai_la_ke_gia_mao/core/errors/app_error.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/game_history.dart';
import 'package:ai_la_ke_gia_mao/features/profile/domain/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> profileJson({
  int played = 4,
  int won = 2,
  int normal = 1,
  int impostor = 1,
  int correct = 2,
}) => {
  'id': 'p1',
  'username': 'Tên dài hợp lệ',
  'avatar_id': 'avatar_01',
  'coins': 123456,
  'xp': 1850,
  'level': 4,
  'games_played': played,
  'games_won': won,
  'normal_wins': normal,
  'impostor_wins': impostor,
  'correct_votes': correct,
  'created_at': '2026-09-01T00:00:00Z',
  'updated_at': '2026-09-01T00:00:00Z',
};

void main() {
  test('derives XP progress and win rate from authoritative totals', () {
    final p = PlayerProfile.fromJson(profileJson());
    expect(p.xpIntoLevel, 350);
    expect(p.xpProgress, .7);
    expect(p.winRate, .5);
  });
  test('zero games has zero win rate', () {
    final p = PlayerProfile.fromJson(
      profileJson(played: 0, won: 0, normal: 0, impostor: 0, correct: 0),
    );
    expect(p.winRate, 0);
  });
  test('rejects inconsistent stats', () {
    expect(
      () => PlayerProfile.fromJson(
        profileJson(played: 1, won: 2, normal: 1, impostor: 1),
      ),
      throwsA(isA<ProfileLoadAppError>()),
    );
  });
  test('parses keyset history page', () {
    final page = GameHistoryPage.fromJson({
      'items': [
        {
          'game_id': 'g1',
          'round_number': 2,
          'finished_at': '2026-09-01T00:00:00Z',
          'winner_team': 'normal',
          'result_reason': 'x',
          'caller_role': 'normal',
          'did_win': true,
          'keyword_vi': 'Táo',
          'keyword_en': 'Apple',
          'category_vi': 'Đồ ăn',
          'category_en': 'Food',
          'xp_gained': 180,
          'coins_gained': 20,
          'player_count': 3,
        },
      ],
      'next_finished_at': '2026-09-01T00:00:00Z',
      'next_game_id': 'g1',
    });
    expect(page.hasMore, isTrue);
    expect(page.items.single.keyword('en'), 'Apple');
  });
}
