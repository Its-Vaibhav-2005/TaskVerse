import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackverse/appearance.dart';
import 'package:trackverse/cloud_ui.dart';
import 'package:trackverse/main.dart' show AppTextScaler;
import 'package:trackverse/settings_page.dart';

void main() {
  test('Rapid font adjustments persist the final selection', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = Appearance();
    final saves = [
      preferences.setTypography(step: 1),
      preferences.setTypography(step: 2, family: 'Lora'),
      preferences.setTypography(step: 4, family: 'JetBrains Mono'),
    ];
    expect(preferences.fontStep, 4);
    expect(preferences.fontFamily, 'JetBrains Mono');
    await Future.wait(saves);
    final restored = Appearance();
    await restored.load();
    expect(restored.fontStep, 4);
    expect(restored.fontFamily, 'JetBrains Mono');
  });
  testWidgets('Tracker dialogs submit and cancel without leaving an overlay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => const TrackerNameDialog(),
                );
              },
              child: const Text('New tracker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('New tracker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('New tracker'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Reading');
    await tester.tap(find.text('Create tracker'));
    await tester.pumpAndSettle();
    expect(result, {'alias': 'Reading', 'copyCurrent': false});
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cloud cards stay compact and large tracker lists build lazily', (
    tester,
  ) async {
    Widget panel(int count) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CloudPanel(
            state: {
              'connected': true,
              'configured': true,
              'activeId': '0',
              'profiles': List.generate(
                count,
                (i) => {
                  'id': '$i',
                  'alias': 'Tracker $i',
                  'sheet_id': 'sheet-$i',
                  'url': 'https://docs.google.com/spreadsheets/d/sheet-$i/edit',
                  'status': 'synced',
                },
              ),
            },
            busy: false,
            onCreate: () {},
            onRename: (_) {},
            action: (_, _, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(panel(1));
    expect(
      tester.getSize(find.byKey(const ValueKey('tracker-card-0'))).height,
      lessThan(260),
    );
    expect(find.byType(SelectableText), findsNothing);
    await tester.pumpWidget(panel(100));
    expect(find.text('Tracker 99'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Typography changes immediately and fits narrow screens at maximum size',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      appearance.fontStep = 0;
      appearance.fontFamily = 'Inter';
      addTearDown(() {
        appearance.fontStep = 0;
        appearance.fontFamily = 'Inter';
      });
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AnimatedBuilder(
          animation: appearance,
          builder: (context, _) => MaterialApp(
            theme: trackVerseTheme(Brightness.dark),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  textScaler: AppTextScaler(appearance.fontStep),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: SettingsPage(
                      trackerName: 'Personal',
                      connected: false,
                      busy: false,
                      browserOnly: true,
                      onMode: (_) {},
                      onFontStep: (delta) => appearance.setTypography(
                        step: appearance.fontStep + delta,
                      ),
                      onExport: () {},
                      onRestore: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final increase = find.byTooltip('Increase font size by 1');
      await tester.ensureVisible(increase);
      for (var i = 0; i < 4; i++) {
        await tester.tap(increase);
        await tester.pumpAndSettle();
      }
      expect(appearance.fontStep, 4);
      expect(find.text('+4 px'), findsOneWidget);
      await tester.ensureVisible(find.text('Reset typography'));
      await tester.tap(find.text('Reset typography'));
      await tester.pumpAndSettle();
      expect(appearance.fontStep, 0);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text(supportEmail), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
