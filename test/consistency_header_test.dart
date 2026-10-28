import 'package:flutter_test/flutter_test.dart';
import 'package:trackverse/mobile/consistency_header.dart';
import 'package:trackverse/model.dart';

void main() {
  test(
    'header curve uses scheduled completion rates and gaps before habit creation',
    () {
      final today = DateTime(2026, 10, 28);
      final h = Habit(
        id: 'read',
        name: 'Read',
        category: 'Learning',
        color: 0,
        icon: 0,
        created: DateTime(2026, 10, 27),
        checks: {'2026-10-27'},
      );
      final rates = headerConsistency([h], today);
      expect(rates.take(19).every((v) => v == null), isTrue);
      expect(rates.sublist(19), [1, 0]);
      final second = Habit(
        id: 'water',
        name: 'Water',
        category: 'Wellness',
        color: 1,
        icon: 1,
        created: today,
        checks: {'2026-10-28'},
      );
      expect(headerConsistency([h, second], today).last, .5);
      expect(headerConsistency([], today).every((v) => v == null), isTrue);
    },
  );
}
