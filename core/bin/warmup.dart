import 'dart:math';
import '../lib/judge.dart';
import '../lib/match.dart';
import '../lib/easy.dart';
import '../lib/policy_match.dart';

Outcome trial(
  int seed,
  Policy policy, {
  bool perfectHint = false,
  bool useHintVotes = true,
  bool easyFirstHint = false,
  bool compareClaimPatterns = false,
  bool enableAnnouncement = false,
  bool independentBotVotes = false,
  void Function(bool)? onAnnouncement,
  int firstHintDay = 3,
  EasyRules? easyRules,
  void Function(int)? onHint,
  void Function(bool)? onAdvice,
  void Function(bool, bool)? onPairedAdvice,
  void Function(List<List<int>>, Set<int>)? auditTeams,
}) => runPolicyMatch(
  seed,
  policy,
  perfectHint: perfectHint,
  useHintVotes: useHintVotes,
  easyFirstHint: easyFirstHint,
  compareClaimPatterns: compareClaimPatterns,
  enableAnnouncement: enableAnnouncement,
  independentBotVotes: independentBotVotes,
  onAnnouncement: onAnnouncement,
  firstHintDay: firstHintDay,
  easyRules: easyRules,
  onHint: onHint,
  onAdvice: onAdvice,
  onPairedAdvice: onPairedAdvice,
  auditTeams: auditTeams,
).outcome!;

void main() {
  final seeds = Random(42);
  const policies = [
    Policy.random,
    Policy.followsClaim,
    Policy.coordinated,
    Policy.simpleBaseline,
  ];
  final counts = {for (final policy in policies) policy: List.filled(3, 0)};
  final differences = {for (final policy in policies) policy: <int>[]};
  for (var i = 0; i < 3000; i++) {
    final seed = seeds.nextInt(1 << 30);
    final results = {
      for (final policy in policies) policy: trial(seed, policy),
    };
    for (final policy in policies) {
      counts[policy]![results[policy]!.index]++;
      differences[policy]!.add(
        (results[Policy.simpleBaseline] == Outcome.village ? 1 : 0) -
            (results[policy] == Outcome.village ? 1 : 0),
      );
    }
  }
  print(
    'policy,village,mafia,draw,baseline_minus_policy_pp,paired_ci95_low,paired_ci95_high',
  );
  for (final p in policies) {
    final d = differences[p]!;
    final mean = d.reduce((a, b) => a + b) / d.length;
    final se = sqrt(
      d.fold(0.0, (s, x) => s + pow(x - mean, 2)) / (d.length * (d.length - 1)),
    );
    final stats = [
      mean,
      mean - 1.96 * se,
      mean + 1.96 * se,
    ].map((x) => (100 * x).toStringAsFixed(2));
    print([p.name, ...counts[p]!, ...stats].join(','));
  }
}
