import 'dart:math';

import 'package:test/test.dart';

import '../lib/match.dart';

Match fixture() => Match.withRoles({
  1: Role.mafia,
  2: Role.mafia,
  3: Role.doctor,
  4: Role.detective,
  5: Role.citizen,
  6: Role.citizen,
  7: Role.citizen,
  8: Role.citizen,
}, Random(1));
Map<int, int> abstain(Match g) => {for (final p in g.alive) p: 0};
void main() {
  test(
    'protection and checks stay private, including a dying detective’s check',
    () {
      final g = fixture();
      g.resolveNight({1: 7, 2: 7}, 7, 1);
      expect(g.publicEvents.last.type, 'NO_DEATH_ANNOUNCE');
      expect(g.publicEvents.last.target, isNull);
      expect(g.publicEvents.any((e) => e.result != null), false);
      g.resolveDay(abstain(g));
      g.resolveNight({1: 4, 2: 4}, 6, 2);
      expect(
        g.narrator.where((e) => e.type == 'DETECTIVE_RESULT').last.result,
        'MAFIA',
      );
      expect(g.publicEvents.last.target, 4);
      expect(g.alive.contains(4), false);
    },
  );
  test('invalid choices leave match unchanged', () {
    final g = fixture();
    final initial = g.narrator.length;
    expect(() => g.resolveNight({1: 2, 2: 2}, 5, 1), throwsArgumentError);
    expect(() => g.resolveNight({1: 5, 2: 5}, 3, 1), throwsArgumentError);
    expect(g.narrator.length, initial);
    g.resolveNight({1: 5, 2: 5}, 5, 1);
    expect(() => g.resolveDay({...abstain(g), 3: 3}), throwsArgumentError);
    g.resolveDay(abstain(g));
    expect(() => g.resolveNight({1: 5, 2: 5}, 5, 1), throwsArgumentError);
  });
  test('ties skip, third skipped night loses before voting', () {
    final g = fixture();
    for (int i = 0; i < 3; i++) {
      g.resolveNight({1: 5, 2: 6}, i.isEven ? 5 : 6, 1);
      if (i < 2) g.resolveDay(abstain(g));
    }
    expect(g.outcome, Outcome.village);
    expect(g.narrator.last.note, 'THREE_TARGETLESS_NIGHTS');
    expect(g.publicEvents.any((e) => e.type == 'MAFIA_WARNING'), false);
  });
  test('saved attacks reset Mafia timer; fifteen quiet rounds draw', () {
    final g = fixture();
    for (int i = 0; i < 15; i++) {
      final p = i.isEven ? 5 : 6;
      g.resolveNight({1: i < 2 ? 0 : p, 2: i < 2 ? 0 : p}, p, 1);
      g.resolveDay(abstain(g));
    }
    expect(g.targetless, 0);
    expect(g.outcome, Outcome.draw);
  });
  test(
    'top tie retains both, abstentions do not count against named votes',
    () {
      final g = fixture();
      g.resolveNight({1: 5, 2: 5}, 5, 1);
      g.resolveDay({...abstain(g), 3: 1, 4: 2});
      expect(g.alive.length, 8);
      g.resolveNight({1: 6, 2: 6}, 6, 1);
      g.resolveDay({...abstain(g), 3: 1});
      expect(g.alive.contains(1), false);
      g.resolveNight({2: 5}, 5, 2);
      g.resolveDay({...abstain(g), 3: 2});
      expect(g.outcome, Outcome.village);
    },
  );
  test('parity ends at dawn', () {
    final g = Match.withRoles({
      1: Role.mafia,
      2: Role.mafia,
      3: Role.doctor,
      4: Role.detective,
      5: Role.citizen,
    }, Random(0));
    g.resolveNight({1: 3, 2: 3}, 5, 1);
    expect(g.outcome, Outcome.mafia);
  });
  test('8 and 15 players finish and repeat for fixed seeds', () {
    for (final (n, k) in [(8, 2), (15, 3)]) {
      for (int seed = 0; seed < 50; seed++) {
        final g = Match.deal(n, k, seed)..play();
        expect(g.narrator.last.type, 'GAME_END');
        final repeat = Match.deal(n, k, seed)..play();
        expect(
          g.narrator.map((e) => e.toJson()),
          repeat.narrator.map((e) => e.toJson()),
        );
      }
    }
  });
}
