import 'dart:math';

import '../lib/judge.dart';
import '../lib/policy_match.dart';

void main(List<String> args) {
  final mode = args.first;
  final count = int.parse(args[1]);
  if (mode == 'silent') {
    final share = double.parse(args[2]);
    final results = List.filled(8, 0);
    for (final seed in starts(152269, 1 << 33, count)) {
      final game = runPolicyMatch(
        seed,
        Policy.hard,
        independentBotVotes: true,
        compareClaimPatterns: true,
        enableAnnouncement: true,
        silentJudge: true,
        informedVoteShare: share,
        onSilentHardComparison: (baseline, candidate, bot) {
          results[(baseline ? 4 : 0) + (candidate ? 2 : 0) + (bot ? 1 : 0)]++;
        },
      );
      if (game.publicEvents.any(
        (e) => e.type == 'ASK_CODEFATHER' || e.type == 'CODEFATHER_ANNOUNCE',
      )) {
        throw StateError('Private advice disclosed');
      }
    }
    print('matches,share,baseline_correct,new_correct,bot_correct,positions');
    for (var i = 0; i < results.length; i++) {
      print(
        [count, share, (i >> 2) & 1, (i >> 1) & 1, i & 1, results[i]].join(','),
      );
    }
    return;
  }

  final near = mode == 'near';
  final policy = near ? Policy.medium : Policy.values.byName(mode);
  final seeds = starts(
    count == 50000 ? 984619 : 507211,
    count == 50000 ? 1 << 35 : 1 << 34,
    count,
  );
  print('policy,${near ? 'near_band' : 'share'},matches,village,mafia,draw');
  for (final share in args.skip(2).map(double.parse)) {
    final outcomes = List.filled(3, 0);
    for (final seed in seeds) {
      final game = runPolicyMatch(
        seed,
        policy,
        informedVoteShare: near ? 1 : share,
        nearVoteBand: near ? share : 0,
        independentBotVotes: true,
        compareClaimPatterns: true,
        enableAnnouncement: policy == Policy.hard,
      );
      outcomes[game.outcome!.index]++;
    }
    print([policy.name, share, count, ...outcomes].join(','));
  }
}

Set<int> starts(int seed, int offset, int count) {
  final rng = Random(seed);
  final seeds = <int>{};
  while (seeds.length < count) {
    seeds.add(offset + rng.nextInt(1 << 30));
  }
  return seeds;
}
