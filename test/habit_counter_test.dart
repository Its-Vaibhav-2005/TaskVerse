import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackverse/main.dart';
import 'package:trackverse/model.dart';

void main() {
  test(
    'Partial progress survives JSON backup and only a complete target finishes a day',
    () {
      final day = DateTime(2026, 10, 24);
      final habit = Habit(
        id: 'water',
        name: 'Drink water',
        category: 'Wellness',
        color: 1,
        icon: 1,
        created: day,
        dailyTarget: 8,
        reminder: {'enabled': true, 'time': '09:30', 'interval': 60},
      );
      habit.setCount(day, 3);
      expect(habit.done(day), false);
      final restored = Habit.fromJson(habit.toJson());
      expect(restored.countOn(day), 3);
      expect(restored.reminder?['time'], '09:30');
      restored.setCount(day, 8);
      expect(habit.countOn(day), 3);
      expect(restored.done(day), true);
      expect(restored.completions(day, day), 1);
      restored.setCount(day, 7);
      expect(restored.done(day), false);
      expect(restored.countOn(DateTime(2026, 10, 25)), 0);
    },
  );

  testWidgets(
    'Create and edit dialog saves daily target and editable reminder cadence',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Habit? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<Habit>(
                    context: context,
                    builder: (_) => HabitDialog(now: DateTime(2026, 10, 24)),
                  );
                },
                child: const Text('Add habit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add habit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Habit name'),
        'Drink water',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Daily target'),
        '8',
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('First reminder'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      await tester.ensureVisible(find.text('Create habit'));
      await tester.tap(find.text('Create habit'));
      await tester.pumpAndSettle();
      expect(result?.dailyTarget, 8);
      expect(result?.reminder, {
        'enabled': true,
        'time': '09:00',
        'interval': 60,
      });
      expect(tester.takeException(), isNull);
    },
  );
}
