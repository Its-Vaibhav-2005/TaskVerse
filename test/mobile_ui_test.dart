import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackverse/appearance.dart';
import 'package:trackverse/mobile/app.dart';
import 'package:trackverse/mobile/controller.dart';
import 'package:trackverse/mobile/store.dart';
import 'package:trackverse/model.dart';

class MemoryStore extends MobileStore {
  final Map<String, MobileWorkspace> items = {};
  @override
  Future<void> save(MobileWorkspace w, {bool archive = false}) async {
    items[w.id] = MobileWorkspace(
      w.id,
      jsonDecode(jsonEncode(w.snapshot)),
      jsonDecode(jsonEncode(w.sync)),
    );
  }

  @override
  Future<List<MobileWorkspace>> load() async => items.values.toList();
  @override
  Future<void> activate(String id) async {}
  @override
  Future<Map<String, dynamic>?> focusDraft(String id) async => null;
  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('editing a scoped habit preserves its month assignments', (
    tester,
  ) async {
    Habit? saved;
    final h = Habit(
      id: 'old',
      name: 'Read',
      category: 'Learning',
      color: 0,
      icon: 0,
      created: DateTime(2020, 1),
      months: {'2020-01-01'},
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                saved = await showModalBottomSheet<Habit>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => MobileHabitEditor(habit: h),
                );
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(saved!.months, {'2020-01-01'});
    await tester.pumpWidget(const SizedBox.shrink());
  });
  Future<MobileController> controller() async {
    final store = MemoryStore();
    // The controller uses an isolated in-memory store, without platform plugins.
    final actual = MobileController(store: store);
    final w = MobileWorkspace('local', {
      'format': 'trackverse',
      'version': 1,
      'alias': 'Personal habits',
      'habits': MobileController.previewHabits(
        DateTime.now(),
      ).map((h) => h.toJson()).toList(),
      'months': [monthKey(DateTime.now())],
      'focusSessions': [],
    }, {});
    await store.save(w);
    actual.workspaces = [w];
    actual.active = w;
    actual.loading = false;
    return actual;
  }

  Future<void> mount(
    WidgetTester tester,
    MobileController c, {
    double width = 390,
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: trackVerseTheme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: MobileApp(controller: c),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Settings creates a separate tracker and can switch back', (
    tester,
  ) async {
    final c = await controller();
    await mount(tester, c);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create tracker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Give your tracker a name.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Work');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(c.workspaces.length, 2);
    expect(c.active!.alias, 'Work');
    expect(c.habits, isEmpty);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal habits'));
    await tester.pumpAndSettle();
    expect(c.habits, hasLength(4));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'phone navigation, daily counts, editor and local-only sync state work',
    (tester) async {
      final c = await controller();
      await mount(tester, c);
      expect(find.text('Small steps.\nBetter days.'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Undo Read a little'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Undo Read a little'));
      await tester.pumpAndSettle();
      expect(c.habits.first.done(DateTime.now()), isFalse);
      await tester.ensureVisible(
        find.byTooltip('Add progress to Stay hydrated'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add progress to Stay hydrated'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Increase count'));
      await tester.tap(find.text('Save progress'));
      await tester.pumpAndSettle();
      expect(c.habits[1].countOn(DateTime.now()), 4);
      for (final label in ['Progress', 'Focus', 'Sync', 'Today']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('New habit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Practice guitar',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create habit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create habit'));
      await tester.pumpAndSettle();
      expect(c.habits.last.name, 'Practice guitar');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );
  testWidgets(
    'small phone and large text keep all four screens usable in dark mode',
    (tester) async {
      final c = await controller();
      await mount(
        tester,
        c,
        width: 320,
        scale: 1.5,
        brightness: Brightness.dark,
      );
      for (final label in ['Today', 'Progress', 'Focus', 'Sync']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Make it your own'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Add progress to Stay hydrated'),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('today')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add progress to Stay hydrated'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save progress'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );
}
