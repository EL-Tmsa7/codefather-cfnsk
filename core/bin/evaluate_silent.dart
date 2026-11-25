import 'dart:math';
import '../lib/judge.dart';
import '../lib/match.dart';
import '../lib/policy_match.dart';

void main(List<String> args) {
  final level = Policy.values.byName(args.single);
  if (![Policy.medium, Policy.hard].contains(level))
    throw ArgumentError('medium or hard');
  final rng = Random(924581), seeds = <int>{};
  while (seeds.length < 50000) seeds.add((1 << 32) + rng.nextInt(1 << 30));
  final wins = [0, 0], draws = [0, 0], paired = [0, 0, 0, 0];
  final advice = [List.filled(4, 0), List.filled(4, 0)];
  for (final seed in seeds) {
    final won = <bool>[];
    for (var arm = 0; arm < 2; arm++) {
      final game = runPolicyMatch(
        seed,
        level,
        independentBotVotes: true,
        compareClaimPatterns: true,
        enableAnnouncement: level == Policy.hard,
        silentJudge: arm == 1,
        onPairedAdvice: (judge, bot) =>
            advice[arm][(judge ? 2 : 0) + (bot ? 1 : 0)]++,
      );
      if (arm == 1 &&
          game.publicEvents.any(
            (e) =>
                e.type == 'ASK_CODEFATHER' || e.type == 'CODEFATHER_ANNOUNCE',
          ))
        throw StateError('Private advice disclosed');
      won.add(game.outcome == Outcome.village);
      if (won.last) wins[arm]++;
      if (game.outcome == Outcome.draw) draws[arm]++;
    }
    paired[(won[0] ? 2 : 0) + (won[1] ? 1 : 0)]++;
  }
  print(
    'level,arm,matches,village,mafia,draw,neither,bot_only,judge_only,both',
  );
  for (var i = 0; i < 2; i++)
    print(
      [
        level.name,
        i == 0 ? 'public' : 'silent',
        seeds.length,
        wins[i],
        seeds.length - wins[i] - draws[i],
        draws[i],
        ...advice[i],
      ].join(','),
    );
  print('paired_wins,neither,silent_only,public_only,both');
  print([level.name, ...paired].join(','));
}
