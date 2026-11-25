import 'dart:math';
import 'warmup.dart';
import '../lib/easy.dart';
import '../lib/judge.dart';

void main(List<String> args) {
  final used = <int>{};
  List<int> starts(int seed, int n) {
    final rng = Random(seed), batch = <int>[];
    while (batch.length < n) {
      final value = rng.nextInt(1 << 30);
      if (used.add(value)) batch.add(value);
    }
    return batch;
  }

  starts(42, 3000);
  starts(17891, 3000);
  starts(86023, 10000);
  final pilot = starts(251129, 10000);
  final legacy = starts(130981, 10000);
  final previous = starts(946037, 50000);
  final compareFirst = args.contains('--first-hint');
  final timing = args.contains('--timing');
  final firstStudy = starts(419903, 50000);
  final timingStudy = starts(783105, 50000);
  final patterns = args.contains('--claims');
  final hardStudy = args.contains('--hard');
  final claimStudy = starts(951307, 50000);
  final seeds = hardStudy
      ? starts(248219, 50000)
      : patterns
      ? claimStudy
      : timing
      ? timingStudy
      : compareFirst
      ? firstStudy
      : args.contains('--pilot')
      ? pilot
      : args.contains('--legacy')
      ? legacy
      : previous;
  print(
    'policy,matches,village,mafia,draw,correct_hints,total_hints,truth_checks,first_hits,first_total,second_hits,second_total,announcements,correct_announcements',
  );
  final variants = hardStudy
      ? ['claim_patterns', 'hard', 'hard_announce']
      : patterns
      ? ['medium_easy_first', 'claim_patterns']
      : timing
      ? ['day3', 'day4']
      : compareFirst
      ? ['medium', 'medium_easy_first']
      : ['easy', 'medium'];
  for (final variant in variants) {
    final medium = variant != 'easy';
    final counts = List.filled(3, 0);
    var correct = 0, hints = 0, checks = 0;
    var announcements = 0, correctAnnouncements = 0;
    final hitsByHint = [0, 0], totalsByHint = [0, 0];
    for (final seed in seeds) {
      var index = 0;
      final outcome = trial(
        seed,
        variant.startsWith('hard')
            ? Policy.hard
            : medium
            ? Policy.medium
            : Policy.simpleBaseline,
        enableAnnouncement: variant == 'hard_announce',
        onAnnouncement: (correct) {
          announcements++;
          if (correct) correctAnnouncements++;
        },
        easyRules: medium ? null : const EasyRules(4, 4, 8),
        easyFirstHint: timing || variant == 'medium_easy_first',
        firstHintDay: variant == 'day4' ? 4 : 3,
        compareClaimPatterns: variant == 'claim_patterns',
        useHintVotes: !args.contains('--pilot'),
        onAdvice: (hit) {
          if (index < 2) {
            totalsByHint[index]++;
            if (hit) hitsByHint[index]++;
          }
          index++;
          hints++;
          if (hit) correct++;
        },
        auditTeams: (teams, truth) {
          if (!teams.any(
            (team) => team.length == truth.length && team.every(truth.contains),
          ))
            throw StateError('True roles excluded at seed $seed');
          checks++;
        },
      );
      counts[outcome.index]++;
    }
    print(
      [
        variant,
        seeds.length,
        ...counts,
        correct,
        hints,
        checks,
        for (int i = 0; i < 2; i++) ...[hitsByHint[i], totalsByHint[i]],
        announcements,
        correctAnnouncements,
      ].join(','),
    );
  }
}
