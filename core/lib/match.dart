import 'dart:math';

import 'judge.dart' show Event;

enum Role { mafia, doctor, detective, citizen }

enum Outcome { village, mafia, draw }

/// A zero ballot is an explicit skip or abstention.
int? uniqueLeader(Iterable<int> ballots) {
  final counts = <int, int>{};
  for (final id in ballots) {
    counts.update(id, (n) => n + 1, ifAbsent: () => 1);
  }
  if (counts.isEmpty) return null;
  final best = counts.values.reduce(max);
  final leaders = counts.keys.where((id) => counts[id] == best);
  return leaders.length == 1 && leaders.first != 0 ? leaders.first : null;
}

class Match {
  final Map<int, Role> roles;
  final Set<int> alive;
  final _events = <Event>[];
  final Random random;
  int round = 1, targetless = 0, inactive = 0;
  int? previousProtection;
  bool night = true, nightDeath = false;
  Outcome? outcome;
  Match.withRoles(Map<int, Role> roster, this.random)
    : roles = Map.unmodifiable(roster),
      alive = {...roster.keys} {
    final mafiaCount = roles.values.where((r) => r == Role.mafia).length;
    if (mafiaCount < 1 ||
        2 * mafiaCount >= roles.length ||
        roles.keys.any((p) => p < 1) ||
        [
          Role.doctor,
          Role.detective,
        ].any((r) => roles.values.where((v) => v == r).length != 1)) {
      throw ArgumentError('Invalid starting roster');
    }
    for (final p in roles.keys) {
      log(
        'DEAL',
        target: p,
        result: roles[p]!.name.toUpperCase(),
        visibility: 'SYSTEM',
      );
    }
  }
  factory Match.deal(int n, int mafia, int seed) {
    if (mafia < 1 || n < mafia + 2 || 2 * mafia >= n)
      throw ArgumentError('Invalid counts');
    final rng = Random(seed);
    final deck = [
      ...List.filled(mafia, Role.mafia),
      Role.doctor,
      Role.detective,
      ...List.filled(n - mafia - 2, Role.citizen),
    ]..shuffle(rng);
    return Match.withRoles({for (var i = 0; i < n; i++) i + 1: deck[i]}, rng);
  }
  List<Event> get narrator => List.unmodifiable(_events);
  Iterable<Event> get publicEvents =>
      _events.where((e) => e.visibility == 'ALL');
  List<int> members(Role r) => alive.where((p) => roles[p] == r).toList();
  void log(
    String type, {
    int? actor,
    int? target,
    String? result,
    String? claimedRole,
    String note = '',
    String visibility = 'ALL',
  }) {
    _events.add(
      Event(
        _events.length + 1,
        round,
        night ? 'NIGHT' : 'DAY',
        type,
        actor: actor,
        target: target,
        result: result,
        claimedRole: claimedRole,
        visibility: visibility,
        note: note,
      ),
    );
  }

  void _ballotKeys(Map<int, int> votes, Iterable<int> voters) {
    if (votes.length != voters.length || !voters.every(votes.containsKey))
      throw ArgumentError('One ballot per eligible voter required');
  }

  void resolveNight(Map<int, int> mafiaVotes, int? protect, int? check) {
    if (!night || outcome != null) throw StateError('Night is closed');
    final mafia = members(Role.mafia),
        doctor = members(Role.doctor).firstOrNull,
        detective = members(Role.detective).firstOrNull;
    _ballotKeys(mafiaVotes, mafia);
    if (mafiaVotes.values.any(
      (p) => p != 0 && (!alive.contains(p) || mafia.contains(p)),
    ))
      throw ArgumentError('Illegal Mafia target');
    if (doctor == null
        ? protect != null
        : !alive.contains(protect) ||
              protect == doctor ||
              protect == previousProtection)
      throw ArgumentError('Illegal protection');
    if (detective == null
        ? check != null
        : !alive.contains(check) || check == detective)
      throw ArgumentError('Illegal check');
    log('NIGHT_START');
    if (targetless == 2) log('MAFIA_WARNING', visibility: 'MAFIA');
    for (final v in mafiaVotes.entries) {
      log(
        'MAFIA_KILL_CHOICE',
        actor: v.key,
        target: v.value == 0 ? null : v.value,
        visibility: 'MAFIA',
      );
    }
    if (doctor != null)
      log(
        'DOCTOR_PROTECT',
        actor: doctor,
        target: protect,
        visibility: 'DOCTOR',
      );
    previousProtection = protect;
    if (detective != null) {
      log(
        'DETECTIVE_CHECK',
        actor: detective,
        target: check,
        visibility: 'DETECTIVE',
      );
      log(
        'DETECTIVE_RESULT',
        actor: detective,
        target: check,
        result: mafia.contains(check) ? 'MAFIA' : 'NOT_MAFIA',
        visibility: 'DETECTIVE',
      );
    }
    final target = uniqueLeader(mafiaVotes.values);
    targetless = target == null ? targetless + 1 : 0;
    nightDeath = target != null && target != protect;
    night = false;
    if (nightDeath) alive.remove(target);
    log('DAY_START');
    log(
      nightDeath ? 'DEATH_ANNOUNCE' : 'NO_DEATH_ANNOUNCE',
      target: nightDeath ? target : null,
    );
    if (targetless >= 3) {
      _finish(Outcome.village, 'THREE_TARGETLESS_NIGHTS');
    } else {
      _checkVictory();
    }
  }

  void resolveDay(Map<int, int> votes) {
    if (night || outcome != null) throw StateError('Day is closed');
    _ballotKeys(votes, alive);
    for (final v in votes.entries) {
      if (v.value != 0 && (v.value == v.key || !alive.contains(v.value)))
        throw ArgumentError('Illegal vote');
    }
    // Publish choices only after all ballots have closed.
    for (final v in votes.entries) {
      log('VOTE', actor: v.key, target: v.value == 0 ? null : v.value);
    }
    final target = uniqueLeader(votes.values.where((p) => p != 0));
    if (target != null) alive.remove(target);
    log(
      target != null
          ? 'ELIMINATE'
          : votes.values.every((p) => p == 0)
          ? 'NO_VOTES'
          : 'VOTE_TIE',
      target: target,
    );
    inactive = nightDeath || target != null ? 0 : inactive + 1;
    _checkVictory();
    if (outcome == null && inactive >= 15)
      _finish(Outcome.draw, 'FIFTEEN_INACTIVE_ROUNDS');
    if (outcome == null) {
      round++;
      night = true;
    }
  }

  void _checkVictory() {
    final m = members(Role.mafia).length;
    if (m == 0) {
      _finish(Outcome.village, 'LAST_MAFIA_OUT');
    } else if (m >= alive.length - m) {
      _finish(Outcome.mafia, 'PARITY');
    }
  }

  void _finish(Outcome winner, String reason) {
    outcome = winner;
    log('GAME_END', note: reason);
  }

  int pick(List<int> options) => options[random.nextInt(options.length)];
  void play({void Function(Match, Map<int, int>, int?, int?)? experimentDay}) {
    while (outcome == null) {
      final mafia = members(Role.mafia);
      final others = alive.where((p) => !mafia.contains(p)).toList();
      final target = pick(others);
      final doctor = members(Role.doctor).firstOrNull,
          detective = members(Role.detective).firstOrNull;
      final protection = doctor == null
          ? null
          : pick(
              alive
                  .where((p) => p != doctor && p != previousProtection)
                  .toList(),
            );
      final check = detective == null
          ? null
          : pick(alive.where((p) => p != detective).toList());
      resolveNight(
        {for (final p in mafia) p: random.nextInt(8) == 0 ? 0 : target},
        protection,
        check,
      );
      if (outcome != null) break;
      final ballots = <int, int>{};
      for (final p in alive.toList()..sort()) {
        final candidates = alive.where((q) => q != p).toList();
        final accused = pick(candidates);
        if (experimentDay == null) log('ACCUSE', actor: p, target: accused);
        ballots[p] = random.nextInt(7) == 0 ? 0 : accused;
      }
      experimentDay?.call(this, ballots, detective, check);
      resolveDay(ballots);
    }
  }
}
