import 'dart:math';

import 'judge.dart';

/// Rank suspects by the likelihood of the simulator's public speech and votes.
List<double> hardOpeningScores(
  int seats,
  List<List<int>> teams,
  Iterable<Event> history,
  List<double> voteWeights, {
  double voteScale = 1,
  double noise = .002,
  int? publishClearsThroughDay,
  double fakeClearShare = 0,
}) {
  final speech = <int, Map<int, int?>>{};
  final nightsWithDeath = <int>{};
  for (final event in history) {
    if (event.visibility != 'ALL') continue;
    if (event.type == 'DEATH_ANNOUNCE') nightsWithDeath.add(event.round);
    if (event.actor == null) continue;
    if (event.type == 'ACCUSE') {
      (speech[event.round] ??= {})[event.actor!] = null;
    } else if (event.type == 'CLAIM_CHECK' && event.target != null) {
      if (event.result == 'MAFIA') {
        (speech[event.round] ??= {})[event.actor!] = event.target;
      } else if (event.result == 'NOT_MAFIA' &&
          publishClearsThroughDay != null &&
          event.round <= publishClearsThroughDay) {
        (speech[event.round] ??= {})[event.actor!] = -event.target!;
      }
    }
  }
  final scores = List.filled(seats + 1, 0.0);
  for (final team in teams) {
    var mafiaLikelihood = exp(
      voteScale * team.fold(0.0, (sum, id) => sum + voteWeights[id]),
    );
    final detectiveLikelihood = List.filled(seats + 1, 1.0);
    for (final day in speech.entries) {
      final round = day.value;
      final checkChoices =
          round.length - (nightsWithDeath.contains(day.key) ? 0 : 1);
      final livingMafia = team.where(round.containsKey).length;
      final innocents = round.length - livingMafia;
      final publishesClears =
          publishClearsThroughDay != null && day.key <= publishClearsThroughDay;
      for (final entry in round.entries) {
        final actor = entry.key;
        final claim = entry.value;
        if (team.contains(actor)) {
          if (claim == null) {
            mafiaLikelihood *= .8;
          } else if (claim < 0) {
            mafiaLikelihood *= .2 * fakeClearShare / (round.length - 1) + noise;
          } else {
            final accusationShare = publishesClears ? 1 - fakeClearShare : 1;
            mafiaLikelihood *= team.contains(claim)
                ? noise
                : .2 * accusationShare / innocents;
          }
        } else if (claim == null) {
          // The night check precedes the public announcement of any death.
          detectiveLikelihood[actor] *= publishesClears
              ? noise
              : 1 - livingMafia / checkChoices;
        } else {
          final matchesTeam = claim > 0
              ? team.contains(claim)
              : !team.contains(-claim);
          for (var detective = 1; detective <= seats; detective++) {
            detectiveLikelihood[detective] *= detective == actor && matchesTeam
                ? 1 / checkChoices
                : noise;
          }
        }
      }
    }
    final weight =
        mafiaLikelihood *
        [
          for (var id = 1; id <= seats; id++)
            if (!team.contains(id)) detectiveLikelihood[id],
        ].reduce((a, b) => a + b);
    for (final id in team) {
      scores[id] += weight;
    }
  }
  return scores;
}
