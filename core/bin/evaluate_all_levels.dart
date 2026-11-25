import '../lib/easy.dart';
import '../lib/judge.dart';
import '../lib/policy_match.dart';
import 'evaluate_followup.dart' show starts;

void main(List<String> args) {
  final count = int.parse(args.first);
  final (sampleSeed, sampleOffset) = switch (args.skip(1)) {
    final options when options.contains('--confirm-baseline') => (193873, 45),
    final options when options.contains('--fresh') => (962741, 44),
    final options when options.contains('--tune-easy') => (221153, 46),
    final options when options.contains('--confirm-easy') => (664687, 47),
    _ => (621917, 43),
  };
  final seeds = starts(sampleSeed, 1 << sampleOffset, count);
  print(
    'level,matches,village,mafia,draw,hints,judge_correct,'
    'bot_correct,judge_only,bot_only,easy_correct,medium_only,easy_only',
  );
  for (final spec in args.skip(1).where((arg) => !arg.startsWith('--'))) {
    final parts = spec.split(':');
    final level = parts.first;
    final randomShare = switch (level) {
      'weak-baseline' => .5,
      'baseline' when parts.length == 2 => double.parse(parts[1]),
      _ => 0.0,
    };
    final policy = switch (level) {
      'baseline' || 'weak-baseline' || 'easy' => Policy.simpleBaseline,
      'medium' => Policy.medium,
      'hard' => Policy.hard,
      _ => throw ArgumentError.value(level),
    };
    final medium = policy == Policy.medium;
    final hard = policy == Policy.hard;
    final comparison = medium && parts.length == 4;
    final specifiedRules = parts.length == 4
        ? EasyRules(
            int.parse(parts[1]),
            int.parse(parts[2]),
            int.parse(parts[3]),
          )
        : null;
    final easy = switch (level) {
      'easy' => specifiedRules ?? const EasyRules(4, 4, 8),
      _ => null,
    };
    final counts = List.filled(3, 0);
    var hints = 0, judgeCorrect = 0, botCorrect = 0;
    var judgeOnly = 0, botOnly = 0;
    var easyCorrect = 0, mediumOnly = 0, easyOnly = 0;
    for (final seed in seeds) {
      final game = runPolicyMatch(
        seed,
        policy,
        baselineRandomShare: randomShare,
        easyRules: easy,
        compareEasyRules: comparison ? specifiedRules : null,
        onEasyMediumComparison: comparison
            ? (medium, easy) {
                if (easy) easyCorrect++;
                if (medium && !easy) mediumOnly++;
                if (easy && !medium) easyOnly++;
              }
            : null,
        compareClaimPatterns: medium,
        independentBotVotes: medium || hard,
        informedVoteShare: hard ? .29 : .15,
        mediumHintVoteBonus: 0,
        enableAnnouncement: hard,
        useActualVoteTarget: hard,
        usePublicOrdinaryVotes: hard,
        preferAnnouncedTarget: hard,
        hardOpeningVoteScale: hard ? 1 : null,
        publishOpeningClears: hard,
        fakeOpeningClearShare: hard ? .5 : 0,
        onAdvice: (correct) {
          hints++;
          if (correct) judgeCorrect++;
        },
        onPairedAdvice: medium || hard
            ? (judge, bot) {
                if (bot) botCorrect++;
                if (judge && !bot) judgeOnly++;
                if (bot && !judge) botOnly++;
              }
            : null,
      );
      counts[game.outcome!.index]++;
    }
    print(
      [
        spec,
        count,
        ...counts,
        hints,
        judgeCorrect,
        if (medium || hard) ...[
          botCorrect,
          judgeOnly,
          botOnly,
        ] else ...[
          '',
          '',
          '',
        ],
        if (comparison) ...[
          easyCorrect,
          mediumOnly,
          easyOnly,
        ] else ...[
          '',
          '',
          '',
        ],
      ].join(','),
    );
  }
}
