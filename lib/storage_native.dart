import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'model.dart';

class HabitStorage {
  String get desktopWorkspaceId => 'local';
  int get desktopRevision => 0;
  Future<void> setCheckIn(String id, String day, bool complete) async {
    throw UnsupportedError('The desktop bridge handles Windows check-ins.');
  }

  final String? databasePath;
  HabitStorage({this.databasePath});
  late Database _db;
  Future<void> open() async {
    if (Platform.isWindows || Platform.isLinux) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }
    final directory = databasePath == null
        ? await getApplicationSupportDirectory()
        : Directory(p.dirname(databasePath!));
    await directory.create(recursive: true);
    _db = await openDatabase(
      databasePath ?? p.join(directory.path, 'trackverse.sqlite3'),
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('CREATE TABLE months (month TEXT PRIMARY KEY)');
        }
      },
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE months (month TEXT PRIMARY KEY)');
        await db.execute(
          'CREATE TABLE habits (id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL, color INTEGER NOT NULL, icon INTEGER NOT NULL, created TEXT NOT NULL, weekdays TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE completions (habit_id TEXT NOT NULL REFERENCES habits(id) ON DELETE CASCADE, day TEXT NOT NULL, PRIMARY KEY(habit_id, day))',
        );
      },
    );
  }

  Future<List<DateTime>> loadMonths() async => (await _db.query(
    'months',
    orderBy: 'month',
  )).map((r) => DateTime.parse(r['month'] as String)).toList();
  Future<void> saveMonths(List<DateTime> months) async {
    await _db.transaction((tx) async {
      await tx.delete('months');
      for (final m in months) {
        await tx.insert('months', {'month': dayKey(m)});
      }
    });
  }

  Future<List<Habit>> load() async {
    final rows = await _db.query('habits', orderBy: 'rowid');
    final checks = await _db.query('completions');
    return rows
        .map(
          (r) => Habit.fromJson({
            ...r,
            'weekdays': jsonDecode(r['weekdays'] as String),
            'checks': checks
                .where((c) => c['habit_id'] == r['id'])
                .map((c) => c['day'])
                .toList(),
          }),
        )
        .toList();
  }

  Future<void> save(List<Habit> habits) async {
    await _db.transaction((tx) async {
      await tx.delete('completions');
      await tx.delete('habits');
      final batch = tx.batch();
      for (final h in habits) {
        final row = h.toJson()..remove('checks');
        row['weekdays'] = jsonEncode(row['weekdays']);
        batch.insert('habits', row);
        for (final day in h.checks) {
          batch.insert('completions', {'habit_id': h.id, 'day': day});
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> close() => _db.close();
}
