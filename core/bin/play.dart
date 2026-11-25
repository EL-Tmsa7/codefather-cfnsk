import 'dart:convert';
import 'dart:io';

import '../lib/match.dart';
import '../lib/policy_match.dart';
import '../lib/judge.dart';
import '../lib/playable_levels.dart';

void main(List<String> args) {
  final numbers = args
      .where((s) => !s.startsWith('--'))
      .map(int.parse)
      .toList();
  final n = numbers.isEmpty ? 15 : numbers[0],
      k = numbers.length < 2 ? 3 : numbers[1],
      seed = numbers.length < 3 ? 42 : numbers[2];
  final level = args.where((s) => s.startsWith('--level=')).firstOrNull;
  final Match game;
  if (level == null) {
    game = Match.deal(n, k, seed)..play();
  } else {
    final selected = PlayableLevel.values.byName(
      level.substring('--level='.length),
    );
    if (n != 15 || k != 3) throw ArgumentError('Level play requires 15/3.');
    final balanced = args.contains('--balanced');
    final silent = args.contains('--silent');
    final ordinaryVotes = args.contains('--ordinary-votes');
    if (balanced || silent || ordinaryVotes) {
      if (selected != PlayableLevel.medium && selected != PlayableLevel.hard) {
        throw ArgumentError('Diagnostic options require medium or hard.');
      }
      final policy = Policy.values.byName(selected.name);
      game = runPolicyMatch(
        seed,
        policy,
        compareClaimPatterns: true,
        independentBotVotes: true,
        informedVoteShare: balanced ? (policy == Policy.medium ? .02 : .3) : 1,
        silentJudge: silent,
        useOrdinaryVotes: ordinaryVotes,
        enableAnnouncement: policy == Policy.hard,
      );
    } else {
      game = playLevel(seed, selected);
    }
  }
  for (final event
      in args.contains('--public') ? game.publicEvents : game.narrator) {
    stdout.writeln(jsonEncode(event.toJson()));
  }
  stderr.writeln(
    'Winner: ${game.outcome!.name} | rounds: ${game.round} | ${game.narrator.last.note}',
  );
}
