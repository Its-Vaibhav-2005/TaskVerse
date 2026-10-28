import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../model.dart';

const historyTab = '_TrackVerse History';
const journalMagic = 'TRACKVERSE_JOURNAL_V1';
const journalColumns = [
  'Snapshot ID',
  'Parent snapshots',
  'Saved at (UTC)',
  'Part',
  'Part count',
  'SHA256',
  'Backup data (gzip/base64)',
];

/// The same append-only backup protocol used by the Electron application.
class BackupJournal {
  static const maxBytes = 8 * 1024 * 1024;

  static Map<String, dynamic> validate(Map<String, dynamic> data) {
    if (data['format'] != 'trackverse' ||
        data['version'] != 1 ||
        data['habits'] is! List ||
        data['months'] is! List ||
        (data['habits'] as List).length > 10000) {
      throw const FormatException('This is not a supported TrackVerse backup.');
    }
    final ids = <String>{};
    for (final value in data['habits'] as List) {
      final h = Habit.fromJson(Map<String, dynamic>.from(value as Map));
      if (h.id.isEmpty ||
          !ids.add(h.id) ||
          h.name.trim().isEmpty ||
          h.name.length > 60 ||
          h.color < 0 ||
          h.color >= habitColors.length ||
          h.icon < 0 ||
          h.icon >= habitIcons.length ||
          h.dailyTarget < 1 ||
          h.dailyTarget > 99 ||
          h.weekdays.isEmpty ||
          h.weekdays.any((d) => d < 1 || d > 7) ||
          h.checks.any((d) => !_day(d)) ||
          h.dailyCounts.entries.any(
            (e) => !_day(e.key) || e.value < 0 || e.value > 99,
          ) ||
          (h.months?.any((d) => !_day(d) || !d.endsWith('-01')) ?? false)) {
        throw const FormatException('The backup contains invalid habit data.');
      }
    }
    for (final m in data['months'] as List) {
      if (m is! String || !_day(m) || !m.endsWith('-01')) {
        throw const FormatException('The backup contains an invalid month.');
      }
    }
    final sessions = data['focusSessions'] ?? [];
    if (sessions is! List ||
        sessions.any(
          (s) =>
              s is! Map ||
              s['id'] is! String ||
              s['habitId'] is! String ||
              s['name'] is! String ||
              s['color'] is! int ||
              s['color'] < 0 ||
              s['color'] > 15 ||
              s['seconds'] is! num ||
              !(s['seconds'] as num).isFinite ||
              s['seconds'] < 0 ||
              s['seconds'] > 10801 ||
              s['started'] is! String ||
              DateTime.tryParse(s['started']) == null,
        )) {
      throw const FormatException(
        'The backup contains invalid focus sessions.',
      );
    }
    return {...data, 'focusSessions': sessions};
  }

  static bool _day(String value) {
    final d = DateTime.tryParse(value);
    return d != null && dayKey(d) == value;
  }

  static Map<String, dynamic> encode(
    Map<String, dynamic> snapshot,
    List<String> parents,
  ) {
    validate(snapshot);
    final bytes = utf8.encode(jsonEncode(snapshot));
    if (bytes.length > maxBytes) {
      throw const FormatException('Backup exceeds 8 MB.');
    }
    final compressed = base64Encode(gzip.encode(bytes));
    if (compressed.length > 1500000) {
      throw const FormatException('Backup is too large for Google Sheets.');
    }
    final id = const Uuid().v4(), count = (compressed.length / 40000).ceil();
    final time = DateTime.now().toUtc().toIso8601String();
    return {
      'id': id,
      'rows': List.generate(
        count,
        (i) => [
          id,
          jsonEncode(parents),
          time,
          '${i + 1}',
          '$count',
          sha256.convert(bytes).toString(),
          compressed.substring(
            i * 40000,
            ((i + 1) * 40000).clamp(0, compressed.length),
          ),
        ],
      ),
    };
  }

  static Future<List<JournalSnapshot>> read(List<List<dynamic>> rows) async {
    if (rows.isEmpty ||
        rows.first.firstOrNull != journalMagic ||
        rows.length < 2 ||
        rows[1].firstOrNull != journalColumns.first ||
        rows.length > 50000) {
      throw const FormatException(
        'The TrackVerse history header is missing or invalid.',
      );
    }
    final groups = <String, List<List<dynamic>>>{};
    for (final r in rows.skip(2)) {
      if (r.isEmpty || r.first == '') continue;
      if (r.length != 7 || !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch('${r[0]}')) {
        throw const FormatException('Invalid backup record.');
      }
      groups.putIfAbsent('${r[0]}', () => []).add(r);
    }
    final snapshots = <JournalSnapshot>[];
    for (final entry in groups.entries) {
      final first = entry.value.first;
      final count = int.tryParse('${first[4]}') ?? 0;
      if (count < 1 || count > 50) {
        throw const FormatException('Invalid backup size.');
      }
      final parts = <int, String>{};
      for (final r in entry.value) {
        final part = int.tryParse('${r[3]}') ?? 0;
        if (part < 1 ||
            part > count ||
            '${r[4]}' != '$count' ||
            r[1] != first[1] ||
            r[5] != first[5] ||
            r[6] is! String ||
            (r[6] as String).length > 40000 ||
            (parts.containsKey(part) && parts[part] != r[6])) {
          throw const FormatException('Conflicting backup records.');
        }
        parts[part] = r[6] as String;
      }
      if (parts.length != count) {
        throw const FormatException(
          'Incomplete backup. Try syncing again later.',
        );
      }
      final packed = base64Decode(
        List.generate(count, (i) => parts[i + 1]!).join(),
      );
      // Limit decompressed data before materializing or parsing remote JSON.
      final bytes = <int>[];
      await for (final chunk in gzip.decoder.bind(Stream.value(packed))) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('Backup exceeds 8 MB.');
        }
        bytes.addAll(chunk);
      }
      if (sha256.convert(bytes).toString() != first[5]) {
        throw const FormatException(
          'Backup checksum failed. Local data is unchanged.',
        );
      }
      final parents = (jsonDecode(first[1] as String) as List).cast<String>();
      if (parents.contains(entry.key)) {
        throw const FormatException('Invalid backup ancestry.');
      }
      snapshots.add(
        JournalSnapshot(
          entry.key,
          parents,
          validate(
            Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map),
          ),
        ),
      );
    }
    final ids = snapshots.map((s) => s.id).toSet();
    if (snapshots.any((s) => s.parents.any((p) => !ids.contains(p)))) {
      throw const FormatException(
        'Backup history is missing a parent version.',
      );
    }
    // Detect cycles even when another independent head exists.
    final pending = {for (final s in snapshots) s.id: s.parents.toSet()};
    while (pending.isNotEmpty) {
      final roots = pending.keys.where((id) => pending[id]!.isEmpty).toSet();
      if (roots.isEmpty) throw const FormatException('Cyclic backup history.');
      pending.removeWhere((id, _) => roots.contains(id));
      for (final parents in pending.values) {
        parents.removeAll(roots);
      }
    }
    return snapshots;
  }

  static List<JournalSnapshot> heads(List<JournalSnapshot> snapshots) {
    final ancestors = snapshots.expand((s) => s.parents).toSet();
    return snapshots.where((s) => !ancestors.contains(s.id)).toList();
  }
}

class JournalSnapshot {
  final String id;
  final List<String> parents;
  final Map<String, dynamic> data;
  JournalSnapshot(this.id, this.parents, this.data);
}
