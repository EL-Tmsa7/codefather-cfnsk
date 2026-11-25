import 'judge.dart';
import 'easy.dart';

/// Only valid at a live decision point, after the narrator checked victory.
class MediumJudge {
  final int n, k;
  final List<List<int>> allTeams;
  MediumJudge(this.n, this.k) : allTeams = teams(n, k).toList();

  List<List<int>> feasible(Iterable<Event> history) {
    final living = {for (int p = 1; p <= n; p++) p};
    final victims = <int>{};
    final checkpoints = <Set<int>>[];
    for (final e in history) {
      if (e.visibility != 'ALL') continue;
      if (e.type == 'DEATH_ANNOUNCE') {
        victims.add(e.target!);
        living.remove(e.target);
      }
      if (e.type == 'ELIMINATE') living.remove(e.target);
      if (e.type == 'NIGHT_START' || e.type == 'VOTE') {
        if (checkpoints.isEmpty || checkpoints.last.length != living.length)
          checkpoints.add({...living});
      }
    }
    checkpoints.add(living);
    return allTeams.where((team) {
      if (team.any(victims.contains)) return false;
      return checkpoints.every((alive) {
        final count = team.where(alive.contains).length;
        return count > 0 && 2 * count < alive.length;
      });
    }).toList();
  }

  int recommend(
    List<Event> publicLog,
    List<int> order,
    List<List<int>> feasibleTeams, {
    bool useHintVotes = true,
    int hintVoteBonus = 32,
  }) {
    final scores = rankScores(
      publicLog,
      order,
      feasibleTeams,
      useHintVotes: useHintVotes,
      hintVoteBonus: hintVoteBonus,
    );
    return order.reduce((a, b) => scores[b]! > scores[a]! ? b : a);
  }

  Map<int, int> rankScores(
    List<Event> publicLog,
    List<int> order,
    List<List<int>> feasibleTeams, {
    bool useHintVotes = true,
    int hintVoteBonus = 32,
  }) {
    final claims = publicLog
        .where(
          (e) =>
              e.visibility == 'ALL' &&
              e.type == 'CLAIM_CHECK' &&
              e.result == 'MAFIA',
        )
        .toList();
    final easy = const EasyRules(
      4,
      4,
      8,
    ).suspicionPoints(publicLog, [for (int i = 1; i <= n; i++) i]);
    final pastHints = <int, int>{};
    if (useHintVotes) {
      for (final e in publicLog.where((e) => e.visibility == 'ALL')) {
        if (e.type == 'ASK_CODEFATHER' && e.target != null)
          pastHints[e.round] = e.target!;
        final advised = pastHints[e.round];
        if (e.type == 'VOTE' &&
            advised != null &&
            e.actor != null &&
            e.actor != advised &&
            e.target != advised)
          easy[e.actor!] = easy[e.actor!]! + hintVoteBonus;
      }
    }
    var best = -1 << 30;
    final support = List.filled(n + 1, 0);
    // Rank legal teams. False public claims remain possible for every role.
    // A coherent innocent claimant may be the sole real detective.
    for (final team in feasibleTeams) {
      final consistency = <int, int>{};
      final otherSpeakers = <int>{};
      for (final c in claims) {
        if (team.contains(c.actor)) continue;
        otherSpeakers.add(c.actor!);
        consistency.update(
          c.actor!,
          (v) => v + (team.contains(c.target) ? 1 : -2),
          ifAbsent: () => team.contains(c.target) ? 1 : -2,
        );
      }
      final credible = consistency.values.fold(0, (a, b) => a > b ? a : b);
      final rank =
          team.fold<int>(0, (s, p) => s + easy[p]!) +
          12 * credible -
          8 * otherSpeakers.length;
      if (rank < best) continue;
      if (rank > best) {
        best = rank;
        support.fillRange(0, support.length, 0);
      }
      for (final id in team) support[id]++;
    }
    if (feasibleTeams.isEmpty) throw StateError('No feasible Mafia team');
    return _rank(order, support, useHintVotes ? easy : {});
  }

  /// Soft constraint: try each possible identity for the single Detective.
  /// Keep every legal team; inconsistencies only affect its ranking.
  int openingAdvice(
    List<Event> log,
    List<int> order,
    List<List<int>> feasibleTeams,
  ) {
    final scores = openingScores(log, order, feasibleTeams);
    return order.reduce((a, b) => scores[b]! > scores[a]! ? b : a);
  }

  Map<int, int> openingScores(
    List<Event> log,
    List<int> order,
    List<List<int>> feasibleTeams,
  ) {
    final claims = log
        .where(
          (e) =>
              e.visibility == 'ALL' &&
              e.type == 'CLAIM_CHECK' &&
              e.result == 'MAFIA' &&
              e.actor != null &&
              e.target != null,
        )
        .toList();
    const rules = EasyRules(4, 4, 8);
    if (claims.isEmpty) return rules.suspicionPoints(log, order);
    final speakers = claims.map((e) => e.actor!).toSet();
    final support = List.filled(n + 1, 0);
    var bestCost = claims.length + 1;
    for (final team in feasibleTeams) {
      // A silent Detective could be any non-Mafia seat without a claim.
      int silent = n - k - speakers.where((p) => !team.contains(p)).length;
      final possible = [
        if (silent > 0) 0,
        ...speakers.where((p) => !team.contains(p)),
      ];
      for (final detective in possible) {
        int cost = 0;
        for (final claim in claims) {
          final targetsMafia = team.contains(claim.target);
          final consistent = claim.actor == detective
              ? targetsMafia
              : team.contains(claim.actor) && !targetsMafia;
          if (!consistent) cost++;
        }
        if (cost > bestCost) continue;
        if (cost < bestCost) {
          bestCost = cost;
          support.fillRange(0, support.length, 0);
        }
        for (final id in team) support[id] += detective == 0 ? silent : 1;
      }
    }
    final points = rules.suspicionPoints(log, order);
    return _rank(order, support, points);
  }

  Map<int, int> _rank(
    List<int> seats,
    List<int> support,
    Map<int, int> points,
  ) {
    // Points are nonnegative and only break ties in team support.
    final stride = 1 + points.values.fold<int>(0, (a, b) => a > b ? a : b);
    return {
      for (final id in seats) id: support[id] * stride + (points[id] ?? 0),
    };
  }
}
