import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackverse/cloud_ui.dart';
import 'package:trackverse/appearance.dart';

void main() {
  testWidgets(
    'Welcome screen offers Google and SQLite-only setup without asking for a sheet link',
    (tester) async {
      tester.view.physicalSize = const Size(420, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var google = 0, local = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: trackVerseTheme(Brightness.dark),
          home: WelcomeScreen(
            busy: false,
            onGoogle: () => google++,
            onLocal: () => local++,
            onCancel: () {},
          ),
        ),
      );
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Set up locally'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Continue with Google'));
      expect(google, 1);
      await tester.tap(find.text('Set up locally'));
      expect(local, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Settings shows independent tracker aliases, links and sync states',
    (tester) async {
      final state = {
        'connected': true,
        'configured': true,
        'activeId': 'regular',
        'identity': {'email': 'test@example.com'},
        'profiles': [
          {
            'id': 'regular',
            'alias': 'Regular',
            'sheet_id': 'sheet-one',
            'url': 'https://docs.google.com/spreadsheets/d/sheet-one/edit',
            'status': 'synced',
          },
          {
            'id': 'exam',
            'alias': 'Exam prep',
            'sheet_id': 'sheet-two',
            'url': 'https://docs.google.com/spreadsheets/d/sheet-two/edit',
            'status': 'pending',
          },
          {
            'id': 'fitness',
            'alias': 'Fitness',
            'sheet_id': 'sheet-three',
            'url': 'https://docs.google.com/spreadsheets/d/sheet-three/edit',
            'status': 'error',
            'error': 'Offline; retrying later.',
          },
        ],
      };
      String? operation, payload;
      await tester.pumpWidget(
        MaterialApp(
          theme: trackVerseTheme(Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CloudPanel(
                state: state,
                busy: false,
                onCreate: () {},
                onRename: (_) {},
                action: (op, data, reload) async {
                  operation = op;
                  payload = data;
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Exam prep'), findsOneWidget);
      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('Saved locally · waiting to sync'), findsOneWidget);
      expect(find.text('Backed up'), findsOneWidget);
      final switchButton = find.text('Switch tracker').first;
      await tester.ensureVisible(switchButton);
      await tester.tap(switchButton);
      expect(operation, 'switchTracker');
      expect(payload, 'exam');
      final deleteButton = find.text('Delete tracker & sheet').first;
      await tester.ensureVisible(deleteButton);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      expect(find.text('Delete Regular?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(operation, 'switchTracker');
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to Trash'));
      await tester.pumpAndSettle();
      expect(operation, 'deleteTracker');
      expect(payload, 'regular');
      expect(tester.takeException(), isNull);
    },
  );
}
