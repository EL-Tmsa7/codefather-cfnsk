import '../lib/judge.dart';
import '../lib/match.dart' show Outcome;
import '../lib/policy_match.dart';
import 'evaluate_followup.dart' show starts;

void main(List<String> args) {
  final count = int.parse(args.first);
  final seeds = starts(364599, count == 50000 ? 1 << 38 : 1 << 37, count);
  final candidates = <(Policy, double, int, bool, bool)>[
    (Policy.medium, .02, 32, false, false),
    for (final share in [.02, .03, .04, .05, .06])
      for (final bonus in [0, 4, 8, 12, 16])
        (Policy.medium, share, bonus, false, false),
    (Policy.hard, .3, 32, false, false),
    (Policy.hard, .3, 32, true, false),
    (Policy.hard, .3, 32, false, true),
    for (final share in [.2, .25, .3, .35, .4])
      (Policy.hard, share, 32, true, true),
    for (final share in [.08, .10, .12, .14, .16, .18, .20])
      (Policy.medium, share, 0, false, false),
    for (final share in [.2, .25, .3, .35, .4])
      (Policy.hard, share, 32, true, true),
  ];
  final indices = args.skip(1).map(int.parse).toList();
  print(
    'candidate,level,share,hint_bonus,actual_target,ordinary_votes,'
    'easy_opening,prefer_announcement,'
    'matches,village,first_total,first_correct,later_total,later_correct,'
    'judge_total,judge_correct,bot_correct',
  );
  for (final index
      in indices.isEmpty
          ? List.generate(candidates.length, (index) => index)
          : indices) {
    final (policy, share, bonus, actualTarget, ordinaryVotes) =
        candidates[index];
    final easyOpening = policy == Policy.medium && index >= 34 && index.isEven;
    final preferAnnouncement = policy == Policy.hard && index >= 41;
    var village = 0;
    var firstTotal = 0, firstCorrect = 0, laterTotal = 0, laterCorrect = 0;
    var judgeTotal = 0, judgeCorrect = 0, botCorrect = 0;
    for (final seed in seeds) {
      var first = true;
      final game = runPolicyMatch(
        seed,
        policy,
        independentBotVotes: true,
        informedVoteShare: share,
        compareClaimPatterns: !easyOpening,
        easyFirstHint: easyOpening,
        enableAnnouncement: policy == Policy.hard,
        mediumHintVoteBonus: bonus,
        useActualVoteTarget: actualTarget,
        usePublicOrdinaryVotes: ordinaryVotes,
        preferAnnouncedTarget: preferAnnouncement,
        onPairedAdvice: (judge, bot) {
          if (first) {
            firstTotal++;
            if (judge) firstCorrect++;
            first = false;
          } else {
            laterTotal++;
            if (judge) laterCorrect++;
          }
          judgeTotal++;
          if (judge) judgeCorrect++;
          if (bot) botCorrect++;
        },
      );
      if (game.outcome == Outcome.village) village++;
    }
    print(
      [
        index,
        policy.name,
        share,
        bonus,
        actualTarget,
        ordinaryVotes,
        easyOpening,
        preferAnnouncement,
        count,
        village,
        firstTotal,
        firstCorrect,
        laterTotal,
        laterCorrect,
        judgeTotal,
        judgeCorrect,
        botCorrect,
      ].join(','),
    );
  }
}
