import 'package:test/test.dart';
import '../lib/judge.dart';
import '../lib/medium.dart';

void main() {
  test(
    'a night victim is innocent; a claim or private check cannot prune a team',
    () {
      final judge = MediumJudge(15, 3);
      expect(judge.feasible([]).length, 455);
      const events = [
        Event(1, 1, 'DAY', 'DEATH_ANNOUNCE', target: 4),
        Event(2, 1, 'DAY', 'CLAIM_CHECK', actor: 2, target: 3, result: 'MAFIA'),
        Event(
          3,
          1,
          'NIGHT',
          'DETECTIVE_RESULT',
          target: 5,
          result: 'MAFIA',
          visibility: 'DETECTIVE',
        ),
      ];
      final teams = judge.feasible(events);
      expect(teams.length, 364);
      expect(teams.every((t) => !t.contains(4)), true);
    },
  );
  test('continuation rules out past parity even after a later expulsion', () {
    const history = [
      Event(1, 1, 'DAY', 'ELIMINATE', target: 6),
      Event(2, 2, 'NIGHT', 'NIGHT_START'),
      Event(3, 2, 'DAY', 'DEATH_ANNOUNCE', target: 5),
      Event(4, 2, 'DAY', 'ELIMINATE', target: 1),
      Event(5, 3, 'NIGHT', 'NIGHT_START'),
    ];
    final judge = MediumJudge(7, 3);
    final teams = judge.feasible(history);
    expect(teams.any((t) => t.join(',') == '1,2,3'), false);
  });
}
