import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackverse/main.dart';
import 'package:trackverse/model.dart';
import 'package:trackverse/appearance.dart';
import 'package:trackverse/storage_native.dart';

class PlanStorage extends HabitStorage {
  List<Habit> habits = [
    Habit(
      id: 'h',
      name: 'Read October',
      category: 'Learning',
      color: 0,
      icon: 0,
      created: DateTime(2026, 1, 1),
    ),
  ];
  List<DateTime> tabs = [DateTime(DateTime.now().year, DateTime.now().month)];
  @override
  Future<void> open() async {}
  @override
  Future<List<Habit>> load() async => habits;
  @override
  Future<List<DateTime>> loadMonths() async => [...tabs];
  @override
  Future<void> save(List<Habit> values) async {
    habits = values;
  }

  @override
  Future<void> saveMonths(List<DateTime> values) async {
    tabs = [...values];
  }

  @override
  Future<void> savePlan(List<Habit> values, List<DateTime> months) async {
    habits = values;
    tabs = [...months];
  }

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('Large typography stays usable on narrow and desktop screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final oldStep = appearance.fontStep, oldFont = appearance.fontFamily;
    appearance.fontStep = 4;
    appearance.fontFamily = 'JetBrains Mono';
    addTearDown(() {
      appearance.fontStep = oldStep;
      appearance.fontFamily = oldFont;
    });
    for (final width in [390.0, 1500.0]) {
      tester.view.physicalSize = Size(width, 1100);
      await tester.pumpWidget(
        MaterialApp(
          theme: trackVerseTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const AppTextScaler(4)),
            child: child!,
          ),
          home: Home(key: ValueKey(width), storage: PlanStorage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('New habit'));
      await tester.tap(find.text('New habit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  test(
    'Month membership controls schedules and survives JSON; font choices persist offline',
    () async {
      final h = Habit(
        id: 'h',
        name: 'Music',
        category: 'Music',
        color: 15,
        icon: 10,
        created: DateTime(2026, 1, 1),
        months: {'2026-10-01'},
      );
      expect(h.scheduled(DateTime(2026, 10, 22)), isTrue);
      expect(h.scheduled(DateTime(2026, 11, 22)), isFalse);
      expect(Habit.fromJson(h.toJson()).months, {'2026-10-01'});
      SharedPreferences.setMockInitialValues({});
      final a = Appearance();
      await a.setTypography(step: 3, family: 'Lora');
      final b = Appearance();
      await b.load();
      expect(b.fontStep, 3);
      expect(b.fontFamily, 'Lora');
      expect(const AppTextScaler(1).scale(13), 14);
      a.dispose();
      b.dispose();
    },
  );
  testWidgets(
    'Fresh months stay isolated, copied months retain habits, and only future tabs can be deleted',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = PlanStorage();
      final original = store.tabs.single;
      await tester.pumpWidget(
        MaterialApp(
          theme: trackVerseTheme(Brightness.light),
          home: Home(storage: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('The consistency curve')).dy,
        greaterThan(tester.getTopLeft(find.byTooltip('Add month')).dy),
      );
      expect(
        tester.getTopLeft(find.text('New habit')).dx,
        greaterThan(1100),
        reason:
            'The primary action belongs at the top right of the tracker card.',
      );
      expect(tester.getTopLeft(find.text('Habit tracker')).dy, lessThan(460));
      expect(
        tester.getTopLeft(find.text('New habit')).dy,
        closeTo(tester.getTopLeft(find.text('All habits')).dy, 10),
      );
      expect(
        tester
            .getSize(
              find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is NavCurvePainter,
              ),
            )
            .height,
        lessThanOrEqualTo(75),
      );
      expect(
        find.byTooltip('Delete ${months[original.month - 1]} ${original.year}'),
        findsNothing,
      );
      await tester.ensureVisible(find.byTooltip('Add month'));
      await tester.tap(find.byTooltip('Add month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start fresh'));
      await tester.pumpAndSettle();
      expect(store.tabs.length, 2);
      expect(store.habits.single.inMonth(store.tabs.last), isFalse);
      expect(store.habits.single.inMonth(original), isTrue);
      await tester.ensureVisible(find.text('New habit'));
      await tester.tap(find.text('New habit'));
      await tester.pumpAndSettle();
      expect(find.text('This month only'), findsOneWidget);
      expect(find.text('All months'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Play piano');
      await tester.tap(find.text('Create habit'));
      await tester.pumpAndSettle();
      expect(store.habits.last.inMonth(store.tabs.last), isTrue);
      expect(store.habits.last.inMonth(original), isFalse);
      final future = store.tabs.last;
      final delete = find.byTooltip(
        'Delete ${months[future.month - 1]} ${future.year}',
      );
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete month'));
      await tester.pumpAndSettle();
      expect(store.tabs, [original]);
      expect(store.habits.first.inMonth(original), isTrue);
      await tester.ensureVisible(find.byTooltip('Add month'));
      await tester.tap(find.byTooltip('Add month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use same habits'));
      await tester.pumpAndSettle();
      expect(store.habits.first.inMonth(store.tabs.last), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
