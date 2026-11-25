import 'dart:math';

enum Policy { random, followsClaim, coordinated, simpleBaseline, medium, hard }

class Event {
  final int seq, round;
  final String phase, type, visibility, note;
  final int? actor, target;
  final String? claimedRole, result;
  const Event(
    this.seq,
    this.round,
    this.phase,
    this.type, {
    this.actor,
    this.target,
    this.claimedRole,
    this.result,
    this.visibility = 'ALL',
    this.note = '',
  });
  Map<String, Object?> toJson() => {
    'seq': seq,
    'round': round,
    'phase': phase,
    'event_type': type,
    'actor': actor,
    'target': target,
    'claimed_role': claimedRole,
    'claimed_result': result,
    'visible_to': visibility,
    'is_bot': actor == null ? null : true,
    'note': note,
  };
}

Iterable<List<int>> teams(int n, int k, [int first = 1]) sync* {
  if (k == 0) {
    yield [];
    return;
  }
  for (int i = first; i <= n - k + 1; i++) {
    for (final tail in teams(n, k - 1, i + 1)) {
      yield [i, ...tail];
    }
  }
}

class Judge {
  final int n, k;
  final Policy policy;
  final List<List<int>> candidates;
  late final List<double> weights;
  final deadAtNight = <int>{};
  final votes = <(int, int)>[];
  final claims = <int>[];
  final traces = <int, List<int>>{};
  bool announced = false;
  List<double>? cache;
  Judge(this.n, this.k, this.policy)
    : candidates = [
        if (policy == Policy.medium || policy == Policy.hard) ...teams(n, k),
      ] {
    weights = List.filled(candidates.length, 1.0);
  }
  void observe(Event e) {
    if (e.visibility != 'ALL') return;
    final t = e.target;
    if (t == null) return;
    if (e.type == 'CLAIM_CHECK' && e.result == 'MAFIA') claims.add(t);
    if (e.type == 'DEATH_ANNOUNCE') {
      deadAtNight.add(t);
      for (var i = 0; i < candidates.length; i++) {
        if (candidates[i].contains(t)) weights[i] = 0;
      }
      cache = null;
    }
    if (e.type == 'VOTE' && e.actor != null) {
      votes.add((e.actor!, t));
      if (policy == Policy.hard) {
        // Divide all likelihoods by the common innocent-voter factor (0.5).
        // Rescaling preserves posterior probabilities and prevents underflow.
        double largest = 0;
        for (var i = 0; i < candidates.length; i++) {
          final team = candidates[i];
          if (team.contains(e.actor))
            weights[i] *= team.contains(t) ? 0.1 : 1.9;
          largest = max(largest, weights[i]);
        }
        if (largest > 0) {
          for (var i = 0; i < weights.length; i++) weights[i] /= largest;
        }
      }
      cache = null;
    }
  }

  List<double> get scores {
    if (cache != null) return cache!;
    final s = List.filled(n + 1, 0.0);
    if (candidates.isNotEmpty) {
      double total = 0;
      for (var i = 0; i < candidates.length; i++) {
        total += weights[i];
        for (final p in candidates[i]) s[p] += weights[i];
      }
      for (var p = 1; p <= n; p++) s[p] /= total;
    } else {
      for (var p = 1; p <= n; p++) s[p] = deadAtNight.contains(p) ? 0 : k / n;
      if (policy == Policy.simpleBaseline) {
        for (final (v, t) in votes) {
          if (deadAtNight.contains(t) && !deadAtNight.contains(v))
            s[v] = min(.90, s[v] + .08);
        }
      }
    }
    return cache = s;
  }

  List<int> announce() {
    if (announced || candidates.isEmpty) return [];
    final suspects = [
      for (int i = 1; i <= n; i++)
        if (scores[i] >= .95) i,
    ];
    if (suspects.length != k) return [];
    announced = true;
    return suspects;
  }
}
