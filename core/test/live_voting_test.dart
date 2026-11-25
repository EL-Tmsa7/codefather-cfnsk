import 'package:test/test.dart';
import '../lib/judge.dart';
import '../lib/match.dart' show Role;
import '../lib/policy_match.dart';

void main() {
  test('Opening clears only expose the detective’s early public results', () {
    var published = 0;
    for (var seed = 0; seed < 12; seed++) {
      final match = runPolicyMatch(
        seed,
        Policy.hard,
        publishOpeningClears: true,
        hardOpeningVoteScale: 1,
      );
      for (final event in match.publicEvents.where(
        (e) => e.type == 'CLAIM_CHECK' && e.result == 'NOT_MAFIA',
      )) {
        published++;
        expect(event.round, lessThanOrEqualTo(3));
        expect(match.roles[event.actor], Role.detective);
        expect(match.roles[event.target], isNot(Role.mafia));
      }
    }
    expect(published, greaterThan(0));
  });

  test('Comparing the first hard hint leaves the public match unchanged', () {
    final original = runPolicyMatch(
      42,
      Policy.hard,
      independentBotVotes: true,
      informedVoteShare: .25,
      enableAnnouncement: true,
      usePublicOrdinaryVotes: true,
    );
    var compared = 0;
    final measured = runPolicyMatch(
      42,
      Policy.hard,
      independentBotVotes: true,
      informedVoteShare: .25,
      enableAnnouncement: true,
      usePublicOrdinaryVotes: true,
      onHardOpeningComparison: (_, _) => compared++,
    );
    expect(compared, 1);
    expect(measured.outcome, original.outcome);
    expect(
      measured.publicEvents.map((e) => e.toJson()),
      original.publicEvents.map((e) => e.toJson()),
    );
  });

  test(
    'Silent hard advice keeps the same public match with ballot evidence',
    () {
      final original = runPolicyMatch(
        42,
        Policy.hard,
        independentBotVotes: true,
        silentJudge: true,
        enableAnnouncement: true,
      );
      var comparisons = 0;
      final measured = runPolicyMatch(
        42,
        Policy.hard,
        independentBotVotes: true,
        silentJudge: true,
        enableAnnouncement: true,
        useOrdinaryVotes: true,
        onSilentHardComparison: (_, _, _) => comparisons++,
      );
      expect(comparisons, greaterThan(0));
      expect(measured.outcome, original.outcome);
      expect(
        measured.publicEvents.map((event) => event.toJson()),
        original.publicEvents.map((event) => event.toJson()),
      );
    },
  );

  test('Zero informed share reproduces the pre-change ballots', () {
    final original = runPolicyMatch(
      42,
      Policy.medium,
      compareClaimPatterns: true,
    );
    final mixed = runPolicyMatch(
      42,
      Policy.medium,
      compareClaimPatterns: true,
      independentBotVotes: true,
      informedVoteShare: 0,
    );
    expect(
      mixed.publicEvents.map((event) => event.toJson()),
      original.publicEvents.map((event) => event.toJson()),
    );
  });

  for (final level in [Policy.medium, Policy.hard]) {
    test('Independent votes reach the day-one tally for ${level.name}', () {
      final old = runPolicyMatch(42, level, compareClaimPatterns: true);
      final live = runPolicyMatch(
        42,
        level,
        compareClaimPatterns: true,
        independentBotVotes: true,
      );
      final before = old.publicEvents.where(
        (e) => e.round == 1 && e.type == 'VOTE',
      );
      final after = live.publicEvents.where(
        (e) => e.round == 1 && e.type == 'VOTE',
      );
      expect(after.map((e) => e.actor), before.map((e) => e.actor));
      expect(
        after.map((e) => e.target).toList(),
        isNot(equals(before.map((e) => e.target).toList())),
      );
      expect(after.every((e) => e.actor != e.target), isTrue);
      expect(live.outcome, isNotNull);
    });
  }
}
