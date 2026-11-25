import '../lib/playable_levels.dart';
import 'evaluate_followup.dart' show starts;

void main(List<String> args) {
  final count = int.parse(args.first);
  final seeds = starts(371693, 1 << 48, count);
  print(
    'mafia_clear_share,judge_assumption,matches,village,mafia,draw,'
    'hints,judge_correct,bot_correct,judge_only,bot_only',
  );
  for (final share in args.skip(1).map(double.parse)) {
    final outcomes = List.filled(3, 0);
    var hints = 0, judgeCorrect = 0, botCorrect = 0;
    var judgeOnly = 0, botOnly = 0;
    for (final seed in seeds) {
      final game = playLevel(
        seed,
        PlayableLevel.hard,
        hardMafiaClearShare: share,
        onPairedAdvice: (judge, bot) {
          hints++;
          if (judge) judgeCorrect++;
          if (bot) botCorrect++;
          if (judge && !bot) judgeOnly++;
          if (bot && !judge) botOnly++;
        },
      );
      outcomes[game.outcome!.index]++;
    }
    print(
      [
        share,
        .5,
        count,
        ...outcomes,
        hints,
        judgeCorrect,
        botCorrect,
        judgeOnly,
        botOnly,
      ].join(','),
    );
  }
}
