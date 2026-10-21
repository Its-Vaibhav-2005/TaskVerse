import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackverse/local_clock.dart';
import 'package:trackverse/appearance.dart';
import 'package:trackverse/model.dart';

void main() {
  testWidgets(
    'Midnight locks yesterday and enables the new local day without restarting',
    (tester) async {
      var systemNow = DateTime(2026, 10, 31, 23, 59, 59);
      final clock = LocalDayClock(readTime: () => systemNow);
      final habit = Habit(
        id: 'h',
        name: 'Walk',
        category: 'Wellness',
        color: 0,
        icon: 0,
        created: DateTime(2026, 10, 1),
      );
      var changes = 0;
      clock.addListener(() => changes++);
      clock.start();
      expect(canCheckIn(habit, DateTime(2026, 10, 31), systemNow), isTrue);
      systemNow = DateTime(2026, 11, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(clock.today, DateTime(2026, 11, 1));
      expect(changes, 1);
      expect(canCheckIn(habit, DateTime(2026, 10, 31), systemNow), isFalse);
      expect(canCheckIn(habit, DateTime(2026, 11, 1), systemNow), isTrue);
      expect(canCheckIn(habit, DateTime(2026, 11, 2), systemNow), isFalse);
      clock.dispose();
    },
  );
  testWidgets('Resume and manual local date changes refresh the day', (
    tester,
  ) async {
    var systemNow = DateTime(2026, 10, 21, 10);
    final clock = LocalDayClock(readTime: () => systemNow)..start();
    systemNow = DateTime(2026, 10, 23, 11);
    clock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(clock.today, DateTime(2026, 10, 23));
    systemNow = DateTime(2026, 10, 22, 12);
    await tester.pump(const Duration(seconds: 1));
    expect(clock.today, DateTime(2026, 10, 22));
    clock.dispose();
  });
  test('Appearance selection persists and reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = Appearance();
    await settings.setMode(ThemeMode.dark);
    final reopened = Appearance();
    await reopened.load();
    expect(reopened.mode, ThemeMode.dark);
    await reopened.setMode(ThemeMode.light);
    await settings.load();
    expect(settings.mode, ThemeMode.light);
    settings.dispose();
    reopened.dispose();
  });
}
