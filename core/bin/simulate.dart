import 'dart:math';

import '../lib/judge.dart';
import '../lib/match.dart';
import '../lib/playable_levels.dart';

void main() {
  const matchCount = 3000;
  const baselines = [Policy.random, Policy.followsClaim, Policy.coordinated];
  final random = Random(42);
  final seeds = <int>{};
  while (seeds.length < matchCount) {
    seeds.add(random.nextInt(1 << 30));
  }
  print(
    'level,baseline,matches_per_policy,level_village_wins,'
    'baseline_village_wins,gain_pp,level_only_wins,baseline_only_wins',
  );
  final stopwatch = Stopwatch()..start();
  for (final level in PlayableLevel.values.skip(1)) {
    final levelWins = [
      for (final seed in seeds)
        playLevel(seed, level).outcome == Outcome.village,
    ];
    final totalWins = levelWins.where((won) => won).length;
    for (final baseline in baselines) {
      var baselineWins = 0, levelOnly = 0, baselineOnly = 0;
      var index = 0;
      for (final seed in seeds) {
        final baselineWon =
            playLevel(seed, level, comparisonBaseline: baseline).outcome ==
            Outcome.village;
        final levelWon = levelWins[index++];
        if (baselineWon) baselineWins++;
        if (levelWon && !baselineWon) levelOnly++;
        if (baselineWon && !levelWon) baselineOnly++;
      }
      final gain = 100 * (totalWins - baselineWins) / matchCount;
      print(
        [
          level.name,
          baseline.name,
          matchCount,
          totalWins,
          baselineWins,
          gain.toStringAsFixed(3),
          levelOnly,
          baselineOnly,
        ].join(','),
      );
    }
  }
  print('# elapsed_ms=${stopwatch.elapsedMilliseconds}');
}
