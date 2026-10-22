import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackverse/main.dart';
import 'package:trackverse/appearance.dart';
import 'package:trackverse/model.dart';
import 'package:trackverse/storage.dart';

class PreviewStorage extends HabitStorage {
  List<Habit> habits = [
    Habit(
      id: 'test',
      name: 'Read',
      category: 'Learning',
      color: 0,
      icon: 0,
      created: DateTime.now(),
    ),
  ];
  @override
  Future<void> open() async {}
  @override
  Future<List<Habit>> load() async => habits;
  @override
  Future<List<DateTime>> loadMonths() async => [
    DateTime(DateTime.now().year, DateTime.now().month),
  ];
  @override
  Future<void> saveMonths(List<DateTime> months) async {}
  @override
  Future<void> save(List<Habit> value) async {
    habits = value;
  }

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('All main screens and creation dialogs inherit dark surfaces', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: trackVerseTheme(Brightness.dark),
        home: Home(storage: PreviewStorage()),
      ),
    );
    await tester.pumpAndSettle();
    void checkDarkPanels() {
      final whitePanels = tester
          .widgetList<Container>(find.byType(Container))
          .where(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).color == Colors.white,
          );
      expect(
        whitePanels,
        isEmpty,
        reason:
            'No screen panel should retain a hard-coded white background in dark mode.',
      );
      expect(tester.takeException(), isNull);
    }

    checkDarkPanels();
    await tester.tap(find.text('New habit').first);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(AlertDialog))).brightness,
      Brightness.dark,
    );
    checkDarkPanels();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add month'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(AlertDialog))).brightness,
      Brightness.dark,
    );
    checkDarkPanels();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights').first);
    await tester.pumpAndSettle();
    checkDarkPanels();
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    checkDarkPanels();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
