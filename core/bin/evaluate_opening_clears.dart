import '../lib/judge.dart';
import '../lib/policy_match.dart';
import 'evaluate_followup.dart' show starts;

void main(List<String> args) {
  final count = int.parse(args.first);
  final seeds = starts(740213, count == 50000 ? 1 << 42 : 1 << 41, count);
  print(
    'policy,matches,village,mafia,draw,first,first_correct,later,'
    'later_correct,bot_correct,both,judge_only,bot_only,neither',
  );
  for (final spec in args.skip(1)) {
    final parts = spec.split(':');
    final mode = parts.first;
    final voteShare = parts.length == 1 ? .25 : double.parse(parts[1]);
    final publish = mode != 'baseline';
    final fakeShare = switch (mode) {
      'baseline' || 'authentic' => 0.0,
      'mimic' => .5,
      _ => throw ArgumentError.value(mode),
    };
    final results = List.filled(3, 0);
    final pairs = List.filled(4, 0);
    var firstCount = 0, firstCorrect = 0, laterCount = 0, laterCorrect = 0;
    var botCorrect = 0;
    for (final seed in seeds) {
      var first = true;
      final game = runPolicyMatch(
        seed,
        Policy.hard,
        independentBotVotes: true,
        informedVoteShare: voteShare,
        enableAnnouncement: true,
        useActualVoteTarget: true,
        usePublicOrdinaryVotes: true,
        preferAnnouncedTarget: true,
        hardOpeningVoteScale: 1,
        publishOpeningClears: publish,
        fakeOpeningClearShare: fakeShare,
        onPairedAdvice: (judge, bot) {
          if (first) {
            firstCount++;
            if (judge) firstCorrect++;
            first = false;
          } else {
            laterCount++;
            if (judge) laterCorrect++;
          }
          if (bot) botCorrect++;
          pairs[judge ? (bot ? 0 : 1) : (bot ? 2 : 3)]++;
        },
      );
      results[game.outcome!.index]++;
    }
    print(
      [
        spec,
        count,
        ...results,
        firstCount,
        firstCorrect,
        laterCount,
        laterCorrect,
        botCorrect,
        ...pairs,
      ].join(','),
    );
  }
}
