import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'model.dart';
import 'desktop_bridge.dart';

// Browser preview only. Installed applications use storage_native.dart / SQLite.
class HabitStorage {
  late SharedPreferences _prefs;
  String desktopWorkspaceId = 'local';
  int desktopRevision = 0;
  List<DateTime> _months = [];
  Future<void> open() async {
    if (!isWindowsDesktop) {
      _prefs = await SharedPreferences.getInstance();
    }
  }

  Future<List<DateTime>> loadMonths() async => isWindowsDesktop
      ? [..._months]
      : (_prefs.getStringList('trackverse-months') ?? [])
            .map(DateTime.parse)
            .toList();
  Future<void> saveMonths(List<DateTime> months) async {
    if (isWindowsDesktop) {
      desktopRevision =
          jsonDecode(
                await desktopRequest(
                  'saveMonths',
                  jsonEncode({
                    'workspaceId': desktopWorkspaceId,
                    'revision': desktopRevision,
                    'months': months.map(dayKey).toList(),
                  }),
                ),
              )
              as int;
      _months = [...months];
      return;
    }
    if (!await _prefs.setStringList(
      'trackverse-months',
      months.map(dayKey).toList(),
    )) {
      throw StateError('Could not save month tabs');
    }
  }

  Future<List<Habit>> load() async {
    dynamic data;
    if (isWindowsDesktop) {
      final snapshot =
          jsonDecode(await desktopRequest('load')) as Map<String, dynamic>;
      desktopWorkspaceId = snapshot['workspaceId'] as String;
      desktopRevision = snapshot['revision'] as int;
      _months = (snapshot['months'] as List)
          .map((m) => DateTime.parse(m as String))
          .toList();
      data = snapshot['habits'];
    } else {
      data = jsonDecode(_prefs.getString('trackverse') ?? '[]');
    }
    return (data as List)
        .map((e) => Habit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> save(List<Habit> habits) async {
    if (isWindowsDesktop) {
      desktopRevision =
          jsonDecode(
                await desktopRequest(
                  'save',
                  jsonEncode({
                    'workspaceId': desktopWorkspaceId,
                    'revision': desktopRevision,
                    'habits': habits.map((h) => h.toJson()).toList(),
                  }),
                ),
              )
              as int;
      return;
    }
    if (!await _prefs.setString(
      'trackverse',
      jsonEncode(habits.map((h) => h.toJson()).toList()),
    )) {
      throw StateError('Could not save habits');
    }
  }

  Future<void> savePlan(List<Habit> habits, List<DateTime> months) async {
    if (isWindowsDesktop) {
      desktopRevision =
          jsonDecode(
                await desktopRequest(
                  'savePlan',
                  jsonEncode({
                    'workspaceId': desktopWorkspaceId,
                    'revision': desktopRevision,
                    'habits': habits.map((h) => h.toJson()).toList(),
                    'months': months.map(dayKey).toList(),
                  }),
                ),
              )
              as int;
      _months = [...months];
    } else {
      await save(habits);
      await saveMonths(months);
    }
  }

  Future<void> close() async {}
  Future<void> setCheckIn(String id, String day, bool complete) async {
    desktopRevision =
        jsonDecode(
              await desktopRequest(
                'checkIn',
                jsonEncode({
                  'workspaceId': desktopWorkspaceId,
                  'revision': desktopRevision,
                  'id': id,
                  'day': day,
                  'complete': complete,
                }),
              ),
            )
            as int;
  }
}
