import 'package:test/test.dart';
import '../lib/easy.dart';
import '../lib/judge.dart';

void main() {
  const rules = EasyRules(4, 4, 8);
  test('private checks never change the recommendation', () {
    const hidden = Event(
      1,
      1,
      'NIGHT',
      'CLAIM_CHECK',
      actor: 2,
      target: 1,
      result: 'MAFIA',
      visibility: 'DETECTIVE',
    );
    expect(rules.recommend([hidden], [1, 2]), 1);
  });
  test('a disproved public accusation raises suspicion of its speaker', () {
    const claim = Event(
      1,
      1,
      'DAY',
      'CLAIM_CHECK',
      actor: 2,
      target: 3,
      result: 'MAFIA',
    );
    const death = Event(2, 2, 'DAY', 'DEATH_ANNOUNCE', target: 3);
    expect(const EasyRules(0, 0, 8).recommend([claim, death], [1, 2]), 2);
  });
}
