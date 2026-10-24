import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:trackverse/storage_native.dart';
import 'package:trackverse/model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SQLite survives reopen, keeps month tabs, and rolls back failed writes',
    () async {
      final temp = await Directory.systemTemp.createTemp('trackverse-test-');
      final path = p.join(temp.path, 'test.sqlite3');
      final first = HabitStorage(databasePath: path);
      await first.open();
      final h = Habit(
        id: 'h',
        name: 'Read',
        category: 'Learning',
        color: 0,
        icon: 0,
        created: DateTime(2026, 10, 1),
        checks: {'2026-10-21'},
        dailyTarget: 8,
        dailyCounts: {'2026-10-22': 3},
        reminder: {'enabled': true, 'time': '09:30', 'interval': 60},
      );
      await first.save([h]);
      await first.saveMonths([DateTime(2026, 10), DateTime(2026, 11)]);
      await first.close();
      final second = HabitStorage(databasePath: path);
      await second.open();
      expect((await second.load()).single.toJson(), h.toJson());
      expect(await second.loadMonths(), [
        DateTime(2026, 10),
        DateTime(2026, 11),
      ]);
      await expectLater(second.save([h, h]), throwsA(anything));
      expect((await second.load()).single.name, 'Read');
      await second.save([]);
      expect(await second.load(), isEmpty);
      await second.close();
      await temp.delete(recursive: true);
    },
  );
}
