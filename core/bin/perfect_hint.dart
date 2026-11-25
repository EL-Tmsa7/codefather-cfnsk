import 'dart:math';
import 'warmup.dart' show trial;
import '../lib/judge.dart';
import '../lib/match.dart';

void main() {
  final seeds = Random(42);
  final frequency = <int, int>{};
  final wins = <int, int>{};
  final outcomes = <Outcome, int>{};
  for (var i = 0; i < 3000; i++) {
    var hints = 0;
    final outcome = trial(
      seeds.nextInt(1 << 30),
      Policy.simpleBaseline,
      perfectHint: true,
      onHint: (round) {
        hints++;
        if (round != hints * 3) throw StateError('Unexpected hint day');
      },
    );
    frequency.update(hints, (v) => v + 1, ifAbsent: () => 1);
    outcomes.update(outcome, (v) => v + 1, ifAbsent: () => 1);
    if (outcome == Outcome.village)
      wins.update(hints, (v) => v + 1, ifAbsent: () => 1);
  }
  print('hints,matches,village_wins');
  for (final count in {0, ...frequency.keys}.toList()..sort()) {
    print('$count,${frequency[count] ?? 0},${wins[count] ?? 0}');
  }
  print('outcome,matches');
  for (final outcome in Outcome.values) {
    print('${outcome.name},${outcomes[outcome] ?? 0}');
  }
}
