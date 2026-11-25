import '../lib/judge.dart';
import '../lib/policy_match.dart';
import 'evaluate_followup.dart' show starts;

void main(List<String> args) {
  final count = args.isEmpty ? 50000 : int.parse(args.single);
  final seeds = starts(184303, 1 << 36, count);
  print(
    'match_level,phase,matches,village,mafia,draw,'
    'both,medium_only,hard_only,neither',
  );
  for (final (policy, share) in [(Policy.medium, .02), (Policy.hard, .3)]) {
    final first = List.filled(4, 0);
    final later = List.filled(4, 0);
    final outcomes = List.filled(3, 0);
    for (final seed in seeds) {
      final game = runPolicyMatch(
        seed,
        policy,
        independentBotVotes: true,
        informedVoteShare: share,
        compareClaimPatterns: true,
        enableAnnouncement: policy == Policy.hard,
        onJudgeComparison: (isFirst, medium, hard) {
          final phase = isFirst ? first : later;
          phase[medium ? (hard ? 0 : 1) : (hard ? 2 : 3)]++;
        },
      );
      outcomes[game.outcome!.index]++;
    }
    for (final (phase, counts) in [('first', first), ('later', later)]) {
      print([policy.name, phase, count, ...outcomes, ...counts].join(','));
    }
  }
}
