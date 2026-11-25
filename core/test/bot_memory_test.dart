import 'package:test/test.dart';
import '../lib/bot_memory.dart';
import '../lib/judge.dart';

void main() {
  const log = [
    Event(1, 1, 'DAY', 'DEATH_ANNOUNCE', target: 3),
    Event(2, 1, 'DAY', 'VOTE', actor: 1, target: 4),
    Event(3, 1, 'DAY', 'CLAIM_CHECK', actor: 5, target: 6, result: 'MAFIA'),
    Event(4, 2, 'DAY', 'VOTE', actor: 4, target: 1),
    Event(
      5,
      3,
      'NIGHT',
      'DETECTIVE_RESULT',
      target: 1,
      visibility: 'DETECTIVE',
    ),
  ];
  test('medium retains departure but forgets old evidence', () {
    final memory = botEvidence(log, 3, Policy.medium);
    expect(memory.map((e) => e.type), ['ELIMINATE', 'VOTE']);
    expect(memory.first.target, 3);
    expect(memory.last.seq, 4);
  });
  test('hard retains old public evidence except votes', () {
    expect(botEvidence(log, 3, Policy.hard).map((e) => e.seq), [1, 3, 4]);
  });
}
