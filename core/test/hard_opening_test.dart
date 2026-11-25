import 'package:test/test.dart';

import '../lib/hard_opening.dart';
import '../lib/judge.dart';

void main() {
  test('incompatible public claims favor a team containing one claimant', () {
    const history = [
      Event(1, 1, 'DAY', 'CLAIM_CHECK', actor: 1, target: 3, result: 'MAFIA'),
      Event(2, 1, 'DAY', 'CLAIM_CHECK', actor: 2, target: 4, result: 'MAFIA'),
      Event(3, 1, 'DAY', 'ACCUSE', actor: 3, target: 1),
      Event(4, 1, 'DAY', 'ACCUSE', actor: 4, target: 2),
      Event(5, 1, 'DAY', 'ACCUSE', actor: 5, target: 4),
    ];
    const teams = [
      [2, 3],
      [3, 4],
    ];
    final weights = List.filled(6, 0.0);
    final scores = hardOpeningScores(5, teams, history, weights);
    expect(scores[2], greaterThan(scores[4]));
    expect(
      hardOpeningScores(5, teams, [
        ...history,
        const Event(
          6,
          1,
          'DAY',
          'CLAIM_CHECK',
          actor: 5,
          target: 2,
          result: 'MAFIA',
          visibility: 'DETECTIVE',
        ),
      ], weights),
      scores,
    );
  });
}
