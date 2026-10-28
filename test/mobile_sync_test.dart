import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackverse/mobile/backup.dart';
import 'package:trackverse/mobile/controller.dart';
import 'package:trackverse/mobile/google_sheets.dart';
import 'package:trackverse/model.dart';

class MemoryGoogle extends MobileGoogleSheets {
  List<List<dynamic>> rows = [
    [journalMagic],
    journalColumns,
  ];
  bool failAfterWrite = false;
  @override
  bool get connected => true;
  @override
  String get accountId => 'same-account';
  @override
  Future<void> restore() async {}
  @override
  Future<void> inspect(String id) async {}
  @override
  Future<List<List<dynamic>>> read(String id) async => rows;
  @override
  Future<void> append(String id, List<dynamic> data) async {
    rows.addAll(data.map((r) => List<dynamic>.from(r as List)));
    if (failAfterWrite) {
      failAfterWrite = false;
      throw const SocketException('connection lost after write');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory temp;
  late MemoryGoogle google;
  final controllers = <MobileController>[];
  Future<MobileController> device(String name) async {
    final c = MobileController(google: google);
    await c.initialize(databasePath: '${temp.path}/$name.sqlite3');
    c.active!.sync = {
      'sheetId': 'sheet',
      'account': 'same-account',
      'dirty': false,
      'revision': 0,
    };
    await c.store.save(c.active!);
    controllers.add(c);
    return c;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('trackverse-mobile-');
    google = MemoryGoogle();
  });
  tearDown(() async {
    for (final c in controllers) {
      await c.store.close();
      c.dispose();
    }
    controllers.clear();
    await temp.delete(recursive: true);
  });
  Habit habit(String name) => Habit(
    id: 'habit',
    name: name,
    category: 'Learning',
    color: 0,
    icon: 0,
    created: DateTime.now(),
  );

  test(
    'new trackers persist independently and switching syncs pending work',
    () async {
      final a = await device('a');
      await a.saveHabit(habit('Personal'));
      final original = a.active!.id;
      await a.createTracker('  Work  ');
      expect(a.active!.alias, 'Work');
      expect(a.habits, isEmpty);
      expect(a.active!.sheetId, isNull);
      final work = a.active!.id;
      await a.saveHabit(habit('Work habit'));
      await a.select(original);
      expect(a.habits.single.name, 'Personal');
      await a.select(work);
      expect(a.habits.single.name, 'Work habit');
      expect(
        BackupJournal.heads(
          await BackupJournal.read(google.rows),
        ).single.data['habits'][0]['name'],
        'Personal',
      );
      expect(a.active!.id, work);
      await a.createTracker('   ');
      expect(a.error, contains('tracker name'));
      expect((await a.store.load()).length, 2);
      expect(await a.store.activeId(), work);
    },
  );

  test(
    'Android and Windows engines exchange edits through the same journal',
    () async {
      final a = await device('android');
      await a.saveHabit(habit('Android created'));
      await a.sync();
      final file = File('${temp.path}/shared-journal.json');
      Future<Map<String, dynamic>> windows(bool edit) async {
        await file.writeAsString(jsonEncode(google.rows));
        final script = '''
        const fs=require('node:fs'),path=require('node:path');
        const {WorkspaceManager}=require('./desktop/workspaces.cjs');
        const {SyncEngine}=require('./desktop/sync-engine.cjs');
        (async()=>{
          let rows=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));
          const manager=new WorkspaceManager(path.join(process.argv[2],'windows'));
          const remote={inspect:async()=>({sharing:'Private'}),read:async()=>rows,append:async(_,data)=>rows.push(...data)};
          const engine=new SyncEngine(manager,remote);
          try {
            const id=manager.add({sheetId:'cross_platform_test_sheet_123',alias:'Shared',account:'same-account'});
            await engine.sync(id,{force:true});
            const received=manager.snapshot(id);
            if(process.argv[3]==='edit') {
              manager.mutate(id,db=>{const habits=db.load();habits[0].name='Windows edited';db.save(habits,true);});
              await engine.sync(id,{force:true});
            }
            console.log(JSON.stringify({rows,received}));
          } finally {engine.stop();manager.close();}
        })().catch(e=>{console.error(e);process.exitCode=1;});
      ''';
        final result = await Process.run(
          Platform.isWindows ? 'node.exe' : 'node',
          ['-e', script, file.path, temp.path, edit ? 'edit' : 'read'],
        );
        expect(result.exitCode, 0, reason: '${result.stderr}');
        final output =
            jsonDecode(result.stdout as String) as Map<String, dynamic>;
        google.rows = (output['rows'] as List)
            .map((r) => List<dynamic>.from(r as List))
            .toList();
        return output['received'] as Map<String, dynamic>;
      }

      expect((await windows(true))['habits'][0]['name'], 'Android created');
      await a.sync();
      expect(a.habits.single.name, 'Windows edited');
      await a.setCount('habit', 1);
      await a.sync();
      final received = await windows(false);
      expect(
        Habit.fromJson(
          Map<String, dynamic>.from(received['habits'][0]),
        ).done(DateTime.now()),
        isTrue,
      );
      expect(
        BackupJournal.heads(await BackupJournal.read(google.rows)),
        hasLength(1),
      );
      expect(a.error, isNull);
    },
  );

  test('two devices push, pull and preserve a local recovery copy', () async {
    final a = await device('a'), b = await device('b');
    await a.saveHabit(habit('Read'));
    await a.sync();
    expect(a.error, isNull);
    await b.sync();
    expect(b.habits.single.name, 'Read');
    await b.setCount('habit', 1);
    await b.sync();
    await a.sync();
    expect(a.habits.single.done(DateTime.now()), isTrue);
    expect(await a.store.recovery(a.active!.id), isNotEmpty);
    expect(
      BackupJournal.heads(await BackupJournal.read(google.rows)),
      hasLength(1),
    );
  });
  test(
    'offline changes on two devices require a choice and never silently replace data',
    () async {
      final a = await device('a'), b = await device('b');
      await a.saveHabit(habit('Read'));
      await a.sync();
      await b.sync();
      await a.saveHabit(habit('Device A'));
      await b.saveHabit(habit('Device B'));
      await a.sync();
      await b.sync();
      expect(b.conflict, isTrue);
      expect(b.habits.single.name, 'Device B');
      await b.sync(resolve: 'local');
      await a.sync();
      expect(a.habits.single.name, 'Device B');
      expect((await BackupJournal.read(google.rows)).length, 3);
    },
  );
  test(
    'uncertain upload is recovered by ID without duplicate snapshots',
    () async {
      final a = await device('a');
      await a.saveHabit(habit('Read'));
      google.failAfterWrite = true;
      await a.sync();
      expect(a.error, isNotNull);
      await a.sync();
      expect(a.error, isNull);
      expect(a.active!.dirty, isFalse);
      expect(await BackupJournal.read(google.rows), hasLength(1));
    },
  );
  test('corruption and wrong-account sync preserve local habits', () async {
    final a = await device('a');
    await a.saveHabit(habit('Local'));
    await a.sync();
    google.rows.last[5] = 'wrong checksum';
    await a.sync();
    expect(a.error, contains('checksum'));
    expect(a.habits.single.name, 'Local');
    a.active!.sync['account'] = 'another-account';
    await a.sync();
    expect(a.error, contains('owns this tracker'));
    expect(a.habits.single.name, 'Local');
  });
  test(
    'portable import creates a separate workspace and rejects malformed records',
    () async {
      final a = await device('a');
      await a.saveHabit(habit('Original'));
      final original = a.active!.id;
      final data = {...a.active!.snapshot, 'alias': 'Imported'};
      await a.importBackup(jsonEncode(data));
      expect(a.active!.id, isNot(original));
      expect(a.workspaces, hasLength(2));
      expect(a.active!.sheetId, isNull);
      await a.importBackup('{"format":"wrong"}');
      expect(a.error, isNotNull);
      expect(a.habits.single.name, 'Original');
    },
  );
  test('JavaScript and Dart read each other’s journal snapshots', () async {
    final a = await device('a');
    await a.saveHabit(habit('Unicode • पढ़ना'));
    final fixture = File('${temp.path}/snapshot.json');
    await fixture.writeAsString(jsonEncode(a.active!.snapshot));
    final script = '''
      const fs=require('node:fs');const j=require('./desktop/sheet-journal.cjs');
      const snapshot=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));
      console.log(JSON.stringify([[j.MAGIC],j.COLUMNS,...j.encodeSnapshot(snapshot).rows]));
    ''';
    final js = await Process.run(Platform.isWindows ? 'node.exe' : 'node', [
      '-e',
      script,
      fixture.path,
    ]);
    expect(js.exitCode, 0, reason: '${js.stderr}');
    final decoded = await BackupJournal.read(
      (jsonDecode(js.stdout as String) as List)
          .map((r) => List<dynamic>.from(r as List))
          .toList(),
    );
    expect(decoded.single.data['habits'][0]['name'], 'Unicode • पढ़ना');
    final dartRows = [
      [journalMagic],
      journalColumns,
      ...(BackupJournal.encode(a.active!.snapshot, [])['rows'] as List),
    ];
    final encoded = File('${temp.path}/rows.json');
    await encoded.writeAsString(jsonEncode(dartRows));
    final check = await Process.run(Platform.isWindows ? 'node.exe' : 'node', [
      '-e',
      "const j=require('./desktop/sheet-journal.cjs');const rows=JSON.parse(require('node:fs').readFileSync(process.argv[1],'utf8'));console.log(j.readJournal(rows).heads[0].snapshot.habits[0].name)",
      encoded.path,
    ]);
    expect(check.exitCode, 0, reason: '${check.stderr}');
    expect(check.stdout, contains('Unicode'));
  });

  test(
    'concurrent journal branches remain intact until an explicit resolution',
    () async {
      final a = await device('a');
      await a.saveHabit(habit('Base'));
      await a.sync();
      final base = a.active!.sync['base'] as String;
      final left = BackupJournal.encode(
        {...a.active!.snapshot, 'alias': 'Left'},
        [base],
      );
      final right = BackupJournal.encode(
        {...a.active!.snapshot, 'alias': 'Right'},
        [base],
      );
      await google.append('sheet', left['rows'] as List);
      await google.append('sheet', right['rows'] as List);
      await a.sync();
      expect(a.conflict, isTrue);
      expect(
        BackupJournal.heads(await BackupJournal.read(google.rows)),
        hasLength(2),
      );
      await a.sync(resolve: 'local');
      expect(a.conflict, isFalse);
      final records = await BackupJournal.read(google.rows);
      expect(records, hasLength(4));
      expect(BackupJournal.heads(records), hasLength(1));
    },
  );

  test(
    'new local work after an uncertain upload stays dirty until its own backup',
    () async {
      final a = await device('a');
      await a.saveHabit(habit('Before disconnect'));
      google.failAfterWrite = true;
      await a.sync();
      await a.saveHabit(habit('Edited offline'));
      await a.sync();
      final records = await BackupJournal.read(google.rows);
      expect(records, hasLength(2));
      expect(
        BackupJournal.heads(records).single.data['habits'][0]['name'],
        'Edited offline',
      );
      expect(a.active!.dirty, isFalse);
    },
  );

  test(
    'focus recovery uses a stable session ID and invalid writes keep SQLite data',
    () async {
      final a = await device('a');
      await a.saveHabit(habit('Read'));
      final session = {
        'id': 'focus-id',
        'habitId': 'habit',
        'name': 'Read',
        'color': 0,
        'seconds': 30,
        'started': DateTime.now().toUtc().toIso8601String(),
      };
      await a.saveFocus(session);
      await a.saveFocus(session);
      expect(a.active!.snapshot['focusSessions'], hasLength(1));
      await a.saveHabit(habit(''));
      expect(a.error, isNotNull);
      expect(a.habits.single.name, 'Read');
      expect((await a.store.load()).single.habits.single.name, 'Read');
    },
  );
  test(
    'changing a daily target updates today without rewriting past history',
    () async {
      final a = await device('a');
      final now = DateTime.now(),
          yesterday = DateTime.now().subtract(const Duration(days: 1));
      final h = Habit(
        id: 'target',
        name: 'Water',
        category: 'Wellness',
        color: 1,
        icon: 1,
        created: yesterday,
        dailyTarget: 8,
        checks: {dayKey(yesterday)},
        dailyCounts: {dayKey(yesterday): 8, dayKey(now): 5},
      );
      await a.saveHabit(h);
      await a.saveHabit(Habit.fromJson({...h.toJson(), 'dailyTarget': 3}));
      expect(a.habits.single.countOn(now), 3);
      expect(a.habits.single.done(now), isTrue);
      expect(a.habits.single.dailyCounts[dayKey(yesterday)], 8);
      await a.saveHabit(
        Habit.fromJson({...a.habits.single.toJson(), 'dailyTarget': 6}),
      );
      expect(a.habits.single.countOn(now), 3);
      expect(a.habits.single.done(now), isFalse);
      expect(a.habits.single.checks, contains(dayKey(yesterday)));
    },
  );
}
