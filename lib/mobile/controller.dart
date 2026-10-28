import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../model.dart';
import 'backup.dart';
import 'google_sheets.dart';
import 'store.dart';

class MobileController extends ChangeNotifier {
  static const preview = bool.fromEnvironment('TRACKVERSE_PREVIEW');
  final MobileStore store;
  final MobileGoogleSheets google;
  List<MobileWorkspace> workspaces = [];
  MobileWorkspace? active;
  bool loading = true, busy = false, editing = false;
  String? error;
  Timer? _timer, _debounce;
  bool _closed = false;
  MobileController({MobileStore? store, MobileGoogleSheets? google})
    : store = store ?? MobileStore(),
      google = google ?? MobileGoogleSheets();
  List<Habit> get habits => active?.habits ?? [];
  String get syncLabel => active?.sync['status'] as String? ?? 'On this device';
  bool get conflict => active?.sync['status'] == 'Choose a version';

  Future<void> initialize({String? databasePath}) async {
    try {
      await store.open(path: databasePath, preview: preview);
      workspaces = await store.load();
      if (workspaces.isEmpty) {
        final now = DateTime.now();
        final initial = MobileWorkspace('local', {
          'format': 'trackverse',
          'version': 1,
          'alias': 'Personal habits',
          'habits': preview
              ? previewHabits(now).map((h) => h.toJson()).toList()
              : [],
          'months': [monthKey(now)],
          'focusSessions': [],
        }, {});
        await store.save(initial);
        workspaces = [initial];
      }
      final id = await store.activeId();
      active =
          workspaces.where((w) => w.id == id).firstOrNull ?? workspaces.first;
      try {
        if (!preview) {
          await google.restore();
        }
      } catch (_) {
        /* Offline local work remains available. */
      }
      _timer = Timer.periodic(const Duration(seconds: 60), (_) => syncAll());
    } catch (e) {
      error = _friendly(e);
    }
    loading = false;
    _notify();
    if (google.connected) unawaited(syncAll());
  }

  static List<Habit> previewHabits(DateTime now) => List.generate(4, (i) {
    final h = Habit(
      id: 'preview-$i',
      name: [
        'Read a little',
        'Stay hydrated',
        'Move your body',
        'A moment of calm',
      ][i],
      category: ['Learning', 'Wellness', 'Fitness', 'Mindfulness'][i],
      color: [0, 3, 1, 4][i],
      icon: [0, 1, 3, 2][i],
      created: now.subtract(const Duration(days: 21)),
      dailyTarget: i == 1 ? 8 : 1,
    );
    for (var d = 1; d <= 21; d++) {
      if ((d + i) % 4 != 0) {
        h.setCount(now.subtract(Duration(days: d)), h.dailyTarget);
      }
    }
    if (i == 0) h.setCount(now, 1);
    if (i == 1) h.setCount(now, 3);
    return h;
  });

  void _notify() {
    if (!_closed) notifyListeners();
  }

  String _friendly(Object e) => e.toString().replaceFirst(
    RegExp(r'^(Bad state|FormatException|Exception):\s*'),
    '',
  );
  Future<void> run(Future<void> Function() action) async {
    if (busy || _closed) return;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
    } catch (e) {
      error = _friendly(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _reload([String? id]) async {
    workspaces = await store.load();
    active = workspaces.firstWhere((w) => w.id == (id ?? active!.id));
  }

  Future<void> select(String id) async {
    await run(() async {
      await store.activate(id);
      await _reload(id);
    });
    if (error == null) await syncAll();
  }

  Future<void> createTracker(String name) => run(() async {
    final alias = name.trim();
    if (alias.isEmpty || alias.length > 60) {
      throw const FormatException(
        'Use a tracker name between 1 and 60 characters.',
      );
    }
    final id = const Uuid().v4();
    await store.save(
      MobileWorkspace(
        id,
        {
          'format': 'trackverse',
          'version': 1,
          'alias': alias,
          'habits': [],
          'months': [monthKey(DateTime.now())],
          'focusSessions': [],
        },
        {'dirty': true, 'revision': 1, 'status': 'On this device'},
      ),
    );
    await store.activate(id);
    await _reload(id);
  });

  Future<void> syncAll() async {
    if (loading || busy || editing || !google.connected) return;
    final ids = workspaces
        .where(
          (w) =>
              w.sheetId != null &&
              (w.id == active?.id || w.dirty) &&
              w.sync['account'] == google.accountId,
        )
        .map((w) => w.id)
        .toList();
    for (final id in ids) {
      if (_closed || busy || editing) return;
      await sync(workspaceId: id);
    }
  }

  Future<void> change(
    Map<String, dynamic> Function(Map<String, dynamic>) update,
  ) => run(() async {
    final w = active!;
    // Make a deep copy so a failed transaction cannot mutate visible data.
    final snapshot = update(
      jsonDecode(jsonEncode(w.snapshot)) as Map<String, dynamic>,
    );
    final months = snapshot['months'] as List;
    final currentMonth = monthKey(DateTime.now());
    if (!months.contains(currentMonth)) {
      months.add(currentMonth);
      months.sort();
    }
    final next = MobileWorkspace(w.id, snapshot, {
      ...w.sync,
      'dirty': true,
      'revision': w.revision + 1,
      'status': w.sheetId == null ? 'On this device' : 'Waiting to sync',
    });
    await store.save(next);
    await _reload();
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => syncAll());
  });
  Future<void> saveHabit(Habit habit) => change((s) {
    final list = (s['habits'] as List);
    final index = list.indexWhere((h) => h['id'] == habit.id);
    if (index >= 0) {
      final previous = Habit.fromJson(
        Map<String, dynamic>.from(list[index] as Map),
      );
      if (previous.dailyTarget != habit.dailyTarget &&
          habit.scheduled(DateTime.now())) {
        habit.setCount(
          DateTime.now(),
          previous.countOn(DateTime.now()).clamp(0, habit.dailyTarget),
        );
      }
    }
    if (index < 0) {
      list.add(habit.toJson());
    } else {
      list[index] = habit.toJson();
    }
    return s;
  });
  Future<void> deleteHabit(String id) => change((s) {
    (s['habits'] as List).removeWhere((h) => h['id'] == id);
    return s;
  });
  Future<void> setCount(String id, int count) => change((s) {
    final now = dayOnly(DateTime.now());
    final list = s['habits'] as List;
    final index = list.indexWhere((h) => h['id'] == id);
    if (index < 0) throw StateError('This habit no longer exists.');
    final h = Habit.fromJson(Map<String, dynamic>.from(list[index] as Map));
    if (!h.scheduled(now) || count < 0 || count > h.dailyTarget) {
      throw StateError('This habit is not scheduled today.');
    }
    h.setCount(now, count);
    list[index] = h.toJson();
    return s;
  });
  Future<void> saveFocus(Map<String, dynamic> session) => change((s) {
    final records = s['focusSessions'] as List;
    records.removeWhere((r) => r['id'] == session['id']);
    records.add(session);
    return s;
  });
  Future<void> connect() async {
    await run(() async {
      await google.connect();
    });
    if (error == null) await syncAll();
  }

  Future<void> disconnect() => run(() async {
    await google.disconnect();
  });
  Future<void> linkNew() async {
    await run(() async {
      final w = active!;
      if (w.sheetId != null) return;
      if (!google.connected) throw StateError('Connect Google first.');
      final id = await google.create(w.alias);
      await store.save(
        MobileWorkspace(w.id, w.snapshot, {
          ...w.sync,
          'sheetId': id,
          'account': google.accountId!,
          'dirty': true,
          'status': 'Waiting to sync',
        }),
      );
      await _reload();
    });
    if (error == null) await sync();
  }

  Future<List<Map<String, dynamic>>> discover() async {
    var files = <Map<String, dynamic>>[];
    await run(() async {
      files = await google.discover();
    });
    return files;
  }

  Future<void> openRemote(String id) async {
    await run(() async {
      if (!google.connected) throw StateError('Connect Google first.');
      final existing = workspaces
          .where(
            (w) => w.sheetId == id && w.sync['account'] == google.accountId!,
          )
          .firstOrNull;
      if (existing != null) {
        await store.activate(existing.id);
        await _reload(existing.id);
        return;
      }
      await google.inspect(id);
      final heads = BackupJournal.heads(
        await BackupJournal.read(await google.read(id)),
      );
      if (heads.length != 1) {
        throw StateError(
          'This sheet has conflicting or empty history. Resolve it on the original device first.',
        );
      }
      final key = const Uuid().v4();
      await store.save(
        MobileWorkspace(key, heads.single.data, {
          'sheetId': id,
          'account': google.accountId!,
          'base': heads.single.id,
          'dirty': false,
          'revision': 0,
          'status': 'Up to date',
          'lastSync': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      await store.activate(key);
      await _reload(key);
    });
  }

  Future<void> importBackup(String json) => run(() async {
    if (utf8.encode(json).length > BackupJournal.maxBytes) {
      throw const FormatException('Backup exceeds 8 MB.');
    }
    final data = BackupJournal.validate(
      Map<String, dynamic>.from(jsonDecode(json) as Map),
    );
    // Import to a separate local workspace; never overwrite a connected tracker.
    final id = const Uuid().v4();
    await store.save(
      MobileWorkspace(id, data, {
        'dirty': true,
        'revision': 1,
        'status': 'On this device',
      }),
    );
    await store.activate(id);
    await _reload(id);
  });
  Future<void> restoreRecovery(int recoveryId) => run(() async {
    final rows = await store.recovery(active!.id);
    final row = rows.firstWhere((r) => r['id'] == recoveryId);
    final data = BackupJournal.validate(jsonDecode(row['snapshot'] as String));
    final id = const Uuid().v4();
    await store.save(
      MobileWorkspace(
        id,
        {...data, 'alias': '${data['alias']} (recovered)'},
        {'dirty': true, 'revision': 1, 'status': 'On this device'},
      ),
    );
    await store.activate(id);
    await _reload(id);
  });

  Future<void> sync({String? resolve, String? workspaceId}) async {
    final target = workspaceId == null
        ? active
        : workspaces.where((w) => w.id == workspaceId).firstOrNull;
    if (loading ||
        busy ||
        editing ||
        target?.sheetId == null ||
        !google.connected ||
        (target?.sync['status'] == 'Choose a version' && resolve == null)) {
      return;
    }
    await run(() async {
      var w = target!;
      final id = w.sheetId!;
      if (w.sync['account'] != google.accountId!) {
        throw StateError(
          'Reconnect the Google account that owns this tracker.',
        );
      }
      await google.inspect(id);
      var history = await BackupJournal.read(await google.read(id));
      var heads = BackupJournal.heads(history);
      final pending = w.sync['pending'] as Map?;
      if (pending != null && history.any((s) => s.id == pending['id'])) {
        w.sync = {
          ...w.sync,
          'base': pending['id'],
          'dirty': w.revision != pending['revision'],
          'pending': null,
        };
        await store.save(w);
      }
      if (resolve == 'remote') {
        if (heads.length != 1) {
          throw StateError(
            'Several devices created versions. Keep this device to combine the history, or recover on the original device.',
          );
        }
        await _applyRemote(w, heads.single);
        return;
      }
      if ((heads.length > 1 ||
              w.dirty &&
                  heads.isNotEmpty &&
                  heads.single.id != w.sync['base']) &&
          resolve != 'local') {
        w.sync['status'] = 'Choose a version';
        await store.save(w);
        await _reload();
        return;
      }
      if (resolve != 'local' &&
          !w.dirty &&
          heads.length == 1 &&
          heads.single.id != w.sync['base']) {
        await _applyRemote(w, heads.single);
        return;
      }
      if (w.dirty || heads.isEmpty || resolve == 'local') {
        var encoded = w.sync['pending'] as Map<String, dynamic>?;
        if (encoded == null ||
            encoded['revision'] != w.revision ||
            resolve == 'local') {
          encoded = {
            ...BackupJournal.encode(
              w.snapshot,
              heads.map((h) => h.id).toList(),
            ),
            'revision': w.revision,
          };
          w.sync['pending'] = encoded;
          await store.save(w);
        }
        await google.append(id, encoded['rows'] as List);
        history = await BackupJournal.read(await google.read(id));
        if (!history.any((s) => s.id == encoded!['id'])) {
          throw StateError(
            'Google has not confirmed the upload. Sync again to verify it.',
          );
        }
        heads = BackupJournal.heads(history);
        w.sync = {
          ...w.sync,
          'base': encoded['id'],
          'dirty': false,
          'pending': null,
        };
      }
      w.sync = {
        ...w.sync,
        'status': heads.length > 1 ? 'Choose a version' : 'Up to date',
        'lastSync': DateTime.now().toUtc().toIso8601String(),
      };
      await store.save(w);
      await _reload();
    });
  }

  Future<void> _applyRemote(MobileWorkspace w, JournalSnapshot head) async {
    await store.save(
      MobileWorkspace(w.id, head.data, {
        ...w.sync,
        'base': head.id,
        'dirty': false,
        'pending': null,
        'revision': w.revision + 1,
        'status': 'Up to date',
        'lastSync': DateTime.now().toUtc().toIso8601String(),
      }),
      archive: true,
    );
    await _reload();
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    _debounce?.cancel();
    google.close();
    unawaited(store.close());
    super.dispose();
  }
}
