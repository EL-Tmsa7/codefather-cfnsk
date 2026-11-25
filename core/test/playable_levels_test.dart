import 'package:test/test.dart';

import '../lib/playable_levels.dart';

void main() {
  for (final level in PlayableLevel.values) {
    test('${level.name} completes and shows only public events', () {
      final match = playLevel(42, level);
      expect(match.outcome, isNotNull);
      expect(
        match.publicEvents.every((event) => event.visibility == 'ALL'),
        isTrue,
      );
      final hints = match.publicEvents
          .where((event) => event.type == 'ASK_CODEFATHER')
          .map((event) => event.round)
          .toList();
      expect(hints, isNotEmpty);
      expect(hints.first, 3);
      expect(hints.every((day) => (day - 3) % 3 == 0), isTrue);
      expect(
        match.publicEvents.map((event) => event.toJson()),
        playLevel(42, level).publicEvents.map((event) => event.toJson()),
      );
    });
  }
}
