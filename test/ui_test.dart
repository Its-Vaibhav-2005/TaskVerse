import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackverse/main.dart';
import 'package:trackverse/model.dart';
import 'package:trackverse/tracker_grid.dart';
import 'package:trackverse/appearance.dart';

void main() {
  testWidgets('Dark grid keeps past check-ins visible but read-only', (
    tester,
  ) async {
    final h = Habit(
      id: 'h',
      name: 'Read',
      category: 'Learning',
      color: 0,
      icon: 0,
      created: DateTime(2026, 10, 1),
      checks: {'2026-10-01'},
    );
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: trackVerseTheme(Brightness.dark),
        home: Scaffold(
          body: TrackerGrid(
            habits: [h],
            month: DateTime(2026, 10),
            now: DateTime(2026, 10, 21),
            busy: false,
            onToggle: (_, _) => taps++,
            onManage: (_, _) {},
          ),
        ),
      ),
    );
    final oldDay = find.byTooltip('Read · 2026-10-01 · Past day · locked');
    expect(
      find.descendant(of: oldDay, matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );
    await tester.tap(oldDay);
    expect(taps, 0);
    expect(tester.takeException(), isNull);
    expect(
      Theme.of(tester.element(find.byType(TrackerGrid))).brightness,
      Brightness.dark,
    );
  });
  testWidgets('Grid is responsive and completed cells toggle', (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = Habit(
      id: 'h',
      name: 'Read 20 pages',
      category: 'Learning',
      color: 0,
      icon: 0,
      created: DateTime(2026, 10, 1),
    );
    DateTime? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerGrid(
            habits: [h],
            month: DateTime(2026, 10),
            now: DateTime(2026, 10, 1),
            busy: false,
            onToggle: (_, d) => tapped = d,
            onManage: (_, s) {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.descendant(
        of: find.byTooltip('Read 20 pages · 2026-10-01'),
        matching: find.byType(InkWell),
      ),
    );
    expect(tapped, DateTime(2026, 10, 1));
  });
  testWidgets('Month dialog defaults to next month and accepts chosen year', (
    tester,
  ) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<DateTime>(
                  context: ctx,
                  builder: (_) => MonthDialog(initial: DateTime(2027, 1)),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('January'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '2028');
    await tester.tap(find.text('Add month'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2028, 1));
  });
}
