import '../lib/judge.dart';
import '../lib/match.dart';
import '../lib/policy_match.dart';
import 'evaluate_followup.dart' show starts;

void main(List<String> args) {
  final count = int.parse(args.first);
  final seeds = starts(913307, count == 50000 ? 1 << 40 : 1 << 39, count);
  print(
    'level,scale,share,matches,village,first_total,first_correct,'
    'later_total,later_correct,bot_correct,both,baseline_only,candidate_only,neither',
  );
  for (final spec in args.skip(1)) {
    final parts = spec.split(':');
    final medium = parts.first == 'medium' || parts.first == 'claims';
    final easyOpening = parts.first == 'medium';
    final scale = double.tryParse(parts.first);
    final share = double.parse(parts[1]);
    final bonus = medium ? int.parse(parts[2]) : 32;
    final pairs = List.filled(4, 0);
    var village = 0;
    var firstTotal = 0, firstCorrect = 0, laterTotal = 0, laterCorrect = 0;
    var botCorrect = 0;
    for (final seed in seeds) {
      var first = true;
      final game = runPolicyMatch(
        seed,
        medium ? Policy.medium : Policy.hard,
        independentBotVotes: true,
        informedVoteShare: share,
        compareClaimPatterns: !easyOpening,
        easyFirstHint: easyOpening,
        mediumHintVoteBonus: bonus,
        enableAnnouncement: !medium,
        useActualVoteTarget: !medium,
        usePublicOrdinaryVotes: !medium,
        preferAnnouncedTarget: !medium,
        hardOpeningVoteScale: scale,
        onHardOpeningComparison: !medium
            ? (baseline, candidate) {
                pairs[baseline ? (candidate ? 0 : 1) : (candidate ? 2 : 3)]++;
              }
            : null,
        onPairedAdvice: (judge, bot) {
          if (first) {
            firstTotal++;
            if (judge) firstCorrect++;
            first = false;
          } else {
            laterTotal++;
            if (judge) laterCorrect++;
          }
          if (bot) botCorrect++;
        },
      );
      if (game.outcome == Outcome.village) village++;
    }
    print(
      [
        medium ? parts.first : 'hard',
        medium ? bonus : (scale ?? 'baseline'),
        share,
        count,
        village,
        firstTotal,
        firstCorrect,
        laterTotal,
        laterCorrect,
        botCorrect,
        ...pairs,
      ].join(','),
    );
  }
}
