import 'package:flutter_test/flutter_test.dart';
import 'package:trackverse/model.dart';

void main() {
  Habit habit({Set<int>? weekdays}) => Habit(
    id: 'test',
    name: 'Read',
    category: 'Learning',
    color: 0,
    icon: 0,
    created: DateTime(2026, 10, 5),
    weekdays: weekdays,
  );
  test('Rates exclude days before creation and respect weekday schedules', () {
    final h = habit(weekdays: {1, 3, 5});
    h.checks.addAll(['2026-10-05', '2026-10-07', '2026-10-06']);
    expect(h.opportunities(DateTime(2026, 10), DateTime(2026, 10, 11)), 3);
    expect(h.completions(DateTime(2026, 10), DateTime(2026, 10, 11)), 2);
    expect(h.opportunities(DateTime(2026, 11), DateTime(2026, 10, 21)), 0);
  });
  test('Streak skips non-scheduled days and gives today time to finish', () {
    final h = habit(weekdays: {1, 3, 5});
    h.checks.addAll(['2026-10-05', '2026-10-07', '2026-10-09']);
    expect(h.streak(DateTime(2026, 10, 12)), 3);
    expect(h.streak(DateTime(2026, 10, 13)), 0);
  });
  test('Leap day and month boundaries use date-based completion keys', () {
    final h = Habit(
      id: 'leap',
      name: 'Walk',
      category: 'Fitness',
      color: 1,
      icon: 3,
      created: DateTime(2028, 2, 28),
    );
    h.checks.addAll(['2028-02-28', '2028-02-29', '2028-03-01']);
    expect(h.opportunities(DateTime(2028, 2), DateTime(2028, 2, 29)), 2);
    expect(h.completions(DateTime(2028, 3), DateTime(2028, 3, 1)), 1);
    expect(h.streak(DateTime(2028, 3, 1)), 3);
    expect(Habit.fromJson(h.toJson()).checks, h.checks);
  });
}
