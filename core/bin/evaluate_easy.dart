import 'dart:math';
import 'warmup.dart' show trial;
import '../lib/easy.dart';
import '../lib/judge.dart';
import '../lib/match.dart';

const options = {
  'contradictions': EasyRules(0, 0, 8),
  'competing_claims': EasyRules(0, 4, 8),
  'claimant_prior': EasyRules(4, 4, 8),
};

void main(List<String> args) {
  final used = <int>{};
  List<int> starts(int seed, [int count = 3000]) {
    final rng = Random(seed), result = <int>[];
    while (result.length < count) {
      final value = rng.nextInt(1 << 30);
      if (used.add(value)) result.add(value);
    }
    return result;
  }

  final tuning = starts(42);
  if (args.contains('--confirm-10000')) {
    starts(17891); // Exclude both previously used samples.
    print('policy,village,mafia,draw');
    final sample = starts(86023, 10000);
    for (final entry in {
      'easy': options['claimant_prior'],
      'baseline': null,
    }.entries) {
      final counts = List<int>.filled(Outcome.values.length, 0);
      for (final seed in sample) {
        counts[trial(
          seed,
          Policy.simpleBaseline,
          easyRules: entry.value,
        ).index]++;
      }
      print([entry.key, ...counts].join(','));
    }
    return;
  }
  int wins(List<int> seeds, EasyRules? rules) => seeds
      .where(
        (seed) =>
            trial(seed, Policy.simpleBaseline, easyRules: rules) ==
            Outcome.village,
      )
      .length;
  print('split,policy,wins,matches');
  print('tune,baseline,${wins(tuning, null)},3000');
  var best = -1;
  late String selected;
  for (final entry in options.entries) {
    final score = wins(tuning, entry.value);
    print('tune,${entry.key},$score,3000');
    if (score > best) {
      best = score;
      selected = entry.key;
    }
  }
  final heldOut = starts(17891);
  print('holdout,baseline,${wins(heldOut, null)},3000');
  print('holdout,$selected,${wins(heldOut, options[selected])},3000');
}
