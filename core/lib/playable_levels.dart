import 'easy.dart';
import 'judge.dart';
import 'match.dart';
import 'policy_match.dart';

enum PlayableLevel { dumb, easy, medium, hard }

Match playLevel(
  int seed,
  PlayableLevel level, {
  double hardMafiaClearShare = .5,
  Policy? comparisonBaseline,
  void Function(bool)? onAdvice,
  void Function(bool, bool)? onPairedAdvice,
}) {
  final medium = level == PlayableLevel.medium;
  final hard = level == PlayableLevel.hard;
  final policy = switch (level) {
    PlayableLevel.dumb || PlayableLevel.easy => Policy.simpleBaseline,
    PlayableLevel.medium => Policy.medium,
    PlayableLevel.hard => Policy.hard,
  };
  return runPolicyMatch(
    seed,
    policy,
    comparisonBaseline: comparisonBaseline,
    baselineRandomShare: level == PlayableLevel.dumb ? .5 : 0,
    easyRules: level == PlayableLevel.easy ? const EasyRules(0, 2, 8) : null,
    compareClaimPatterns: medium,
    independentBotVotes: medium || hard,
    informedVoteShare: hard ? .29 : .15,
    mediumHintVoteBonus: 0,
    enableAnnouncement: hard && comparisonBaseline == null,
    useActualVoteTarget: hard,
    usePublicOrdinaryVotes: hard,
    preferAnnouncedTarget: hard,
    hardOpeningVoteScale: hard ? 1 : null,
    publishOpeningClears: hard,
    fakeOpeningClearShare: hard ? hardMafiaClearShare : 0,
    assumedFakeOpeningClearShare: hard ? .5 : null,
    onAdvice: onAdvice,
    onPairedAdvice: onPairedAdvice,
  );
}
