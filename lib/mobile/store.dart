import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../model.dart';
import 'backup.dart';

class MobileWorkspace {
  final String id;
  Map<String, dynamic> snapshot;
  Map<String, dynamic> sync;
  MobileWorkspace(this.id, this.snapshot, this.sync);
  String get alias => snapshot['alias'] as String? ?? 'Personal habits';
  List<Habit> get habits => (snapshot['habits'] as List)
      .map((h) => Habit.fromJson(Map<String, dynamic>.from(h as Map)))
      .toList();
  String? get sheetId => sync['sheetId'] as String?;
  bool get dirty => sync['dirty'] == true;
  int get revision => sync['revision'] as int? ?? 0;
}

class MobileStore {
  late Database db;
  Future<void> open({String? path, bool preview = false}) async {
    db = await openDatabase(
      path ??
          p.join(
            await getDatabasesPath(),
            preview
                ? 'trackverse-preview.sqlite3'
                : 'trackverse-mobile.sqlite3',
          ),
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE workspaces (id TEXT PRIMARY KEY, snapshot TEXT NOT NULL, sync TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE recovery (id INTEGER PRIMARY KEY AUTOINCREMENT, workspace TEXT NOT NULL, saved TEXT NOT NULL, snapshot TEXT NOT NULL)',
        );
      },
    );
  }

  Future<List<MobileWorkspace>> load() async => (await db.query('workspaces'))
      .map(
        (r) => MobileWorkspace(
          r['id'] as String,
          jsonDecode(r['snapshot'] as String),
          jsonDecode(r['sync'] as String),
        ),
      )
      .toList();
  Future<String?> activeId() async =>
      (await db.query(
            'settings',
            where: 'key = ?',
            whereArgs: ['active'],
          )).firstOrNull?['value']
          as String?;
  Future<void> activate(String id) => db
      .insert('settings', {
        'key': 'active',
        'value': id,
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});

  Future<Map<String, dynamic>?> focusDraft(String id) async {
    final row = (await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['focus.$id'],
    )).firstOrNull;
    return row == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(row['value'] as String) as Map);
  }

  Future<void> saveFocusDraft(String id, Map<String, dynamic>? draft) async {
    if (draft == null) {
      await db.delete('settings', where: 'key = ?', whereArgs: ['focus.$id']);
    } else {
      await db.insert('settings', {
        'key': 'focus.$id',
        'value': jsonEncode(draft),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> save(MobileWorkspace workspace, {bool archive = false}) async {
    BackupJournal.validate(workspace.snapshot);
    await db.transaction((tx) async {
      if (archive) {
        final old = (await tx.query(
          'workspaces',
          where: 'id = ?',
          whereArgs: [workspace.id],
        )).firstOrNull;
        if (old != null) {
          await tx.insert('recovery', {
            'workspace': workspace.id,
            'saved': DateTime.now().toUtc().toIso8601String(),
            'snapshot': old['snapshot'],
          });
        }
      }
      await tx.insert('workspaces', {
        'id': workspace.id,
        'snapshot': jsonEncode(workspace.snapshot),
        'sync': jsonEncode(workspace.sync),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, Object?>>> recovery(String id) => db.query(
    'recovery',
    where: 'workspace = ?',
    whereArgs: [id],
    orderBy: 'id DESC',
    limit: 20,
  );
  Future<void> close() => db.close();
}
