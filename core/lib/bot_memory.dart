import 'judge.dart';

/// Both bots know who is still in play. Older departures can be remembered
/// without remembering whether the departure was a night death.
List<Event> botEvidence(Iterable<Event> history, int round, Policy level) {
  if (level != Policy.medium && level != Policy.hard)
    throw ArgumentError.value(level);
  final result = <Event>[];
  for (final e in history) {
    if (e.visibility != 'ALL') continue;
    if (e.round >= round - 1) {
      result.add(e);
      continue;
    }
    if (level == Policy.hard) {
      if (e.type != 'VOTE') result.add(e);
    } else if (e.type == 'DEATH_ANNOUNCE') {
      result.add(Event(e.seq, e.round, e.phase, 'ELIMINATE', target: e.target));
    } else if (e.type == 'ELIMINATE' || e.type == 'NIGHT_START') {
      result.add(e);
    }
  }
  return result;
}
