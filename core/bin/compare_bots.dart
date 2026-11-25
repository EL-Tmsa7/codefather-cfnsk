import 'dart:math';
import '../lib/judge.dart';
import '../lib/policy_match.dart';
import 'evaluate_followup.dart' show starts;
import 'warmup.dart' show trial;

void main(List<String> args) {
  if (args.isNotEmpty && args.first == '--balanced') {
    compareBalanced(args.length == 1 ? 50000 : int.parse(args[1]));
    return;
  }
  final rng = Random(40721), seeds = <int>{};
  // Prior experiments used seeds below 2^30.
  while (seeds.length < 50000) {
    seeds.add((1 << 30) + rng.nextInt(1 << 30));
  }
  print('level,matches,no_hint,both,judge_only,bot_only,neither');
  for (final level in [Policy.medium, Policy.hard]) {
    final counts = List.filled(4, 0);
    var noHint = 0;
    for (final seed in seeds) {
      var matched = false;
      trial(
        seed,
        level,
        compareClaimPatterns: true,
        onPairedAdvice: (judge, bot) {
          matched = true;
          counts[judge ? (bot ? 0 : 1) : (bot ? 2 : 3)]++;
        },
      );
      if (!matched) noHint++;
    }
    print([level.name, seeds.length, noHint, ...counts].join(','));
  }
}

void compareBalanced(int count) {
  final seeds = starts(184303, 1 << 36, count);
  print(
    'level,informed_vote_share,matches,village,mafia,draw,'
    'no_hint,both,judge_only,bot_only,neither',
  );
  for (final (level, share) in [(Policy.medium, .02), (Policy.hard, .3)]) {
    final counts = List.filled(4, 0);
    final outcomes = List.filled(3, 0);
    var noHint = 0;
    for (final seed in seeds) {
      var hadHint = false;
      final game = runPolicyMatch(
        seed,
        level,
        independentBotVotes: true,
        informedVoteShare: share,
        compareClaimPatterns: true,
        enableAnnouncement: level == Policy.hard,
        onPairedAdvice: (judge, bot) {
          hadHint = true;
          counts[judge ? (bot ? 0 : 1) : (bot ? 2 : 3)]++;
        },
      );
      outcomes[game.outcome!.index]++;
      if (!hadHint) noHint++;
    }
    print([level.name, share, count, ...outcomes, noHint, ...counts].join(','));
  }
}
