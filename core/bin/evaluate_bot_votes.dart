import 'dart:math';
import '../lib/judge.dart';
import 'warmup.dart' show trial;

void main(List<String> args) {
  final policy = Policy.values.byName(args.single);
  if (![Policy.medium, Policy.hard].contains(policy))
    throw ArgumentError('medium or hard');
  final seeds = <int>{}, rng = Random(739031);
  while (seeds.length < 50000) {
    seeds.add((1 << 31) + rng.nextInt(1 << 30));
  }
  print('policy,independent_votes,matches,village,mafia,draw');
  for (final enabled in [false, true]) {
    final counts = List.filled(3, 0);
    for (final seed in seeds) {
      final result = trial(
        seed,
        policy,
        compareClaimPatterns: true,
        enableAnnouncement: policy == Policy.hard,
        independentBotVotes: enabled,
      );
      counts[result.index]++;
    }
    print([policy.name, enabled, seeds.length, ...counts].join(','));
  }
}
