import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackverse/appearance.dart';
import 'package:trackverse/theme_gallery.dart';

void main() {
  test(
    'System is the first-run default and chosen theme survives reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final a = Appearance();
      await a.load();
      expect(a.mode, ThemeMode.system);
      await a.setPreset('Tokyo Night');
      await a.setMode(ThemeMode.dark);
      final b = Appearance();
      await b.load();
      expect(b.presetName, 'Tokyo Night');
      expect(b.mode, ThemeMode.dark);
      await b.setMode(ThemeMode.system);
      final c = Appearance();
      await c.load();
      expect(c.mode, ThemeMode.system);
    },
  );
  test('Every requested theme has paired high-contrast body text', () {
    expect(themePresets.length, 43);
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
    }

    for (final t in themePresets) {
      for (final brightness in Brightness.values) {
        final p = t.palette(brightness);
        expect(
          contrast(p['text']!, p['surface']!),
          greaterThanOrEqualTo(7),
          reason: t.name,
        );
        expect(
          contrast(p['muted']!, p['surface']!),
          greaterThanOrEqualTo(4.5),
          reason: t.name,
        );
      }
    }
  });
  testWidgets(
    'Theme gallery filters requested skins and remains usable on a narrow display',
    (tester) async {
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: trackVerseTheme(Brightness.light),
          home: const Scaffold(body: ThemeGallery()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Digital Melody');
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w)=>w is Text && w.data=='Digital Melody'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
