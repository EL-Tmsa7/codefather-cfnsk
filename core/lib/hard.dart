import 'dart:math';

import 'judge.dart';

/// Approximate Bayesian model conditional on public claims, ballots and
/// the teams still feasible under the game's hard constraints.
List<double> hardPosterior(
  int n,
  List<List<int>> teams,
  Iterable<Event> history, {
  List<double>? ordinaryVoteWeights,
  Map<int, int>? announcedVoteTargets,
}) {
  final claims = <Event>[];
  final againstAdvice = List.filled(n + 1, 0.0);
  final advice = <int, int>{};
  for (final e in history) {
    if (e.visibility != 'ALL') continue;
    if (e.type == 'ASK_CODEFATHER' && e.target != null)
      advice[e.round] = e.target!;
    if (e.type == 'CLAIM_CHECK' &&
        e.actor != null &&
        e.target != null &&
        e.result == 'MAFIA')
      claims.add(e);
    final target = announcedVoteTargets?[e.round] ?? advice[e.round];
    if (e.type == 'VOTE' &&
        target != null &&
        e.actor != null &&
        e.actor != target) {
      // Likelihood ratios, allowing occasional dissent by an innocent voter.
      againstAdvice[e.actor!] += e.target == target
          ? log(.10 / .98)
          : log(.90 / .02);
    }
  }
  if (teams.isEmpty) throw StateError('No feasible team');
  final logWeights = <double>[];
  for (final team in teams) {
    final detectorRatios = <int, double>{};
    double weight = 0;
    for (final id in team) {
      weight += againstAdvice[id] + (ordinaryVoteWeights?[id] ?? 0);
    }
    // Condition on a public accusation. Marginalise over one unknown
    // Detective drawn uniformly from the non-Mafia seats. Claims are soft.
    for (final c in claims) {
      final mafiaTarget = team.contains(c.target);
      if (team.contains(c.actor)) {
        weight += mafiaTarget ? log(.02) : log(12.0);
      } else {
        detectorRatios.update(
          c.actor!,
          (v) => v * (mafiaTarget ? 40 : .08),
          ifAbsent: () => mafiaTarget ? 40 : .08,
        );
      }
    }
    final innocents = n - team.length;
    final sum = detectorRatios.values.fold<double>(
      (innocents - detectorRatios.length).toDouble(),
      (a, b) => a + b,
    );
    logWeights.add(weight + log(sum / innocents));
  }
  final peak = logWeights.reduce(max), probabilities = List.filled(n + 1, 0.0);
  double total = 0;
  for (var i = 0; i < teams.length; i++) {
    final w = exp(logWeights[i] - peak);
    total += w;
    for (final id in teams[i]) probabilities[id] += w;
  }
  return probabilities.map((x) => x / total).toList();
}

/// Public ordinary ballots have different likelihoods under the simulator's
/// independent-village and random-Mafia voting policies.
double ordinaryVoteWeight(
  int voter,
  int? target,
  Map<int, num> scores,
  double followProbability,
) {
  final legal = scores.keys.where((seat) => seat != voter).toList();
  final best = legal.map((seat) => scores[seat]!).reduce(max);
  final leaders = legal.where((seat) => scores[seat] == best).toList();
  final randomVote = target == null ? 1 / 7 : 6 / (7 * legal.length);
  final informedVote = leaders.contains(target) ? 1 / leaders.length : 0;
  // Leave a small probability for behavior outside the simulated policy.
  final informedShare = .9 * followProbability;
  final villageVote =
      (1 - informedShare) * randomVote + informedShare * informedVote;
  return log(randomVote / villageVote);
}
