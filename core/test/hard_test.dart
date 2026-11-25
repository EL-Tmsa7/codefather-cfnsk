import 'package:test/test.dart';
import '../lib/hard.dart';
import '../lib/judge.dart';
import '../lib/medium.dart';

void main() {
  test('uniform prior, night exclusion and private information boundary', () {
    final medium = MediumJudge(15, 3);
    final prior = hardPosterior(15, medium.feasible([]), []);
    for (final p in prior.skip(1)) expect(p, closeTo(.2, 1e-12));
    const events = [Event(1, 1, 'DAY', 'DEATH_ANNOUNCE', target: 2)];
    final candidates = medium.feasible(events);
    final p = hardPosterior(15, candidates, events);
    expect(p[2], 0);
    expect(p.reduce((a, b) => a + b), closeTo(3, 1e-10));
    expect(
      hardPosterior(15, candidates, [
        ...events,
        const Event(
          2,
          1,
          'DAY',
          'CLAIM_CHECK',
          actor: 1,
          target: 4,
          result: 'MAFIA',
          visibility: 'SYSTEM',
        ),
      ]),
      p,
    );
  });
  test('dissent changes probability without eliminating a legal team', () {
    final medium = MediumJudge(8, 2);
    final probabilities = hardPosterior(8, medium.feasible([]), const [
      Event(1, 3, 'DAY', 'ASK_CODEFATHER', target: 2),
      Event(2, 3, 'DAY', 'VOTE', actor: 1, target: 3),
      Event(3, 3, 'DAY', 'VOTE', actor: 4, target: 2),
    ]);
    expect(probabilities[1], greaterThan(probabilities[4]));
    expect(probabilities[4], greaterThan(0));
  });
  test('an announced vote target takes precedence over the hint', () {
    final medium = MediumJudge(8, 2);
    final probabilities = hardPosterior(
      8,
      medium.feasible([]),
      const [
        Event(1, 3, 'DAY', 'ASK_CODEFATHER', target: 2),
        Event(2, 3, 'DAY', 'VOTE', actor: 1, target: 3),
        Event(3, 3, 'DAY', 'VOTE', actor: 4, target: 2),
      ],
      announcedVoteTargets: const {3: 3},
    );
    expect(probabilities[4], greaterThan(probabilities[1]));
  });
}
