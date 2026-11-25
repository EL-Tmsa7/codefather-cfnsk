import 'judge.dart' show Event;

/// Public suspicion points used for ranking, not calibrated probabilities.
class EasyRules {
  final int claimantPoints, competingClaimPoints, disprovedPoints;
  const EasyRules(
    this.claimantPoints,
    this.competingClaimPoints,
    this.disprovedPoints,
  );

  int recommend(Iterable<Event> events, List<int> tieOrder) {
    final points = suspicionPoints(events, tieOrder);
    return tieOrder.reduce((a, b) => points[b]! > points[a]! ? b : a);
  }

  Map<int, int> suspicionPoints(Iterable<Event> events, List<int> tieOrder) {
    final nightVictims = <int>{};
    final claims = <Event>[], votes = <Event>[];
    final claimants = <int>{};
    for (final e in events) {
      if (e.visibility != 'ALL') continue;
      if (e.type == 'DEATH_ANNOUNCE' && e.target != null)
        nightVictims.add(e.target!);
      if (e.actor == null || e.target == null) continue;
      if (e.type == 'VOTE') votes.add(e);
      if (e.type == 'CLAIM_CHECK' && e.result == 'MAFIA') {
        claims.add(e);
        claimants.add(e.actor!);
      }
    }
    final points = {for (final id in tieOrder) id: 0};
    void add(int id, int delta) {
      if (points.containsKey(id)) points[id] = points[id]! + delta;
    }

    for (final vote in votes) {
      if (nightVictims.contains(vote.target)) add(vote.actor!, 1);
    }
    for (final speaker in claimants) {
      add(speaker, claimantPoints);
      if (claimants.length > 1) add(speaker, competingClaimPoints);
    }
    for (final claim in claims) {
      if (nightVictims.contains(claim.target))
        add(claim.actor!, disprovedPoints);
      // A night victim was innocent; their earlier accusation is soft evidence only.
      if (nightVictims.contains(claim.actor))
        add(claim.target!, disprovedPoints);
    }
    return points;
  }
}
