import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'model.dart';
import 'storage.dart';
import 'tracker_grid.dart';
import 'desktop_bridge.dart';
import 'appearance.dart';
import 'local_clock.dart';
import 'cloud_ui.dart';

const ink = Color(0xFF252735);
const muted = Color(0xFF92939F);
const purple = Color(0xFF32816A);
const line = Color(0xFFEEEFF3);
const canvas = Color(0xFFF8F9FC);
const months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const weekColors = [
  Color(0xFF58A28B),
  Color(0xFF9980C6),
  Color(0xFFD08D83),
  Color(0xFFD4A359),
  Color(0xFF8E9CA8),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appearance.load();
  runApp(const TrackVerse());
}

class TrackVerse extends StatelessWidget {
  const TrackVerse({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appearance,
    builder: (context, _) => MaterialApp(
      title: 'TrackVerse',
      debugShowCheckedModeBanner: false,
      themeAnimationDuration: Duration.zero,
      theme: trackVerseTheme(Brightness.light),
      darkTheme: trackVerseTheme(Brightness.dark),
      themeMode: appearance.mode,
      home: const Home(),
    ),
  );
}

class Home extends StatefulWidget {
  final HabitStorage? storage;
  const Home({super.key, this.storage});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final storage = widget.storage ?? HabitStorage();
  List<Habit> habits = [];
  final localClock = LocalDayClock();
  DateTime get now => localClock.today;
  AppPalette get colors => AppPalette(context);
  Color get ink => colors.text;
  Color get muted => colors.muted;
  Color get line => colors.border;
  Color get canvas => colors.background;
  Color get purple => colors.accent;
  late DateTime month = DateTime(now.year, now.month);
  List<DateTime> monthTabs = [];
  int page = 0;
  String category = 'All habits';
  String query = '';
  bool loading = true, busy = false;
  String? loadError;
  final searchController = TextEditingController();
  Map<String, dynamic> cloud = {};
  bool cloudBusy = false, needsWelcome = false, refreshingCloud = false;
  String? cloudError;
  Timer? cloudPoll;
  List<Map<String, dynamic>> get profiles => (cloud['profiles'] as List? ?? [])
      .map((p) => Map<String, dynamic>.from(p))
      .toList();
  Map<String, dynamic> get activeProfile =>
      profiles.where((p) => p['id'] == cloud['activeId']).firstOrNull ??
      {'id': 'local', 'alias': 'Personal habits'};
  @override
  void initState() {
    super.initState();
    localClock.addListener(onLocalDayChanged);
    localClock.start();
    if (isWindowsDesktop) {
      cloudPoll = Timer.periodic(Duration(seconds: 3), (_) => refreshCloud());
    }
    init();
  }

  Future<void> refreshCloud() async {
    if (!mounted ||
        !isWindowsDesktop ||
        busy ||
        cloudBusy ||
        loading ||
        refreshingCloud) {
      return;
    }
    refreshingCloud = true;
    try {
      final next =
          jsonDecode(await desktopRequest('cloudState'))
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => cloud = next);
      final selected = activeProfile;
      if (ModalRoute.of(context)?.isCurrent == true &&
          (next['activeId'] != storage.desktopWorkspaceId ||
              selected['revision'] != storage.desktopRevision)) {
        await init();
      }
    } catch (_) {
      /* Local work remains available while the desktop connection refreshes. */
    } finally {
      refreshingCloud = false;
    }
  }

  Future<void> cloudAction(
    String operation,
    String payload,
    bool reload,
  ) async {
    if (busy || cloudBusy) return;
    setState(() {
      cloudBusy = true;
      busy = true;
      cloudError = null;
    });
    try {
      await desktopRequest(operation, payload);
      final next =
          jsonDecode(await desktopRequest('cloudState'))
              as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        cloud = next;
        needsWelcome = next['onboarded'] != true;
      });
      if (reload) {
        category = 'All habits';
        query = '';
        searchController.clear();
        month = DateTime(now.year, now.month);
        await init();
      }
    } catch (e) {
      final text = e.toString();
      final index = text.lastIndexOf('Error: ');
      final friendly = index < 0 ? text : text.substring(index + 7);
      if (mounted) {
        setState(() => cloudError = friendly);
        if (!needsWelcome) message(friendly);
      }
    } finally {
      if (mounted) {
        setState(() {
          cloudBusy = false;
          busy = false;
        });
      }
    }
  }

  Future<void> createTracker() async {
    if (busy || cloudBusy) return;
    if (cloud['connected'] != true) {
      setState(() => page = 2);
      message('Connect Google in Settings to create a backed-up tracker.');
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TrackerNameDialog(),
    );
    if (result != null) {
      await cloudAction('createTracker', jsonEncode(result), true);
    }
  }

  Future<void> renameTracker(Map<String, dynamic> profile) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TrackerNameDialog(alias: profile['alias'] as String),
    );
    if (result != null) {
      await cloudAction(
        'renameTracker',
        jsonEncode({'id': profile['id'], 'alias': result['alias']}),
        false,
      );
    }
  }

  Widget trackerSelector() => PopupMenuButton<String>(
    tooltip: 'Switch tracker',
    onSelected: (id) => id == '__new__'
        ? createTracker()
        : cloudAction('switchTracker', id, true),
    itemBuilder: (_) => [
      ...profiles.map(
        (p) => PopupMenuItem(
          value: p['id'] as String,
          enabled: !busy,
          child: Row(
            children: [
              Icon(
                p['sheet_id'] == null
                    ? Icons.storage_outlined
                    : Icons.cloud_outlined,
                size: 16,
              ),
              SizedBox(width: 9),
              Flexible(
                child: Text(
                  p['alias'] as String,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      PopupMenuItem(
        value: '__new__',
        enabled: !busy,
        child: Text('+ New tracker'),
      ),
    ],
    child: SizedBox(
      width: 155,
      child: Row(
        children: [
          Expanded(
            child: Text(
              activeProfile['alias'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
          Icon(Icons.expand_more, size: 16, color: muted),
        ],
      ),
    ),
  );

  void onLocalDayChanged() {
    if (!mounted) return;
    setState(() {});
    final currentMonth = DateTime(now.year, now.month);
    if (!loading && !monthTabs.contains(currentMonth)) {
      selectMonth(currentMonth);
    }
  }

  Future<void> toggleCheckIn(Habit habit, DateTime day) async {
    localClock.refresh();
    if (busy) return;
    if (!canCheckIn(habit, day, DateTime.now())) {
      message('Only today can be changed. Previous days are locked.');
      return;
    }
    final previous = habit.done(day);
    setState(() {
      busy = true;
      previous
          ? habit.checks.remove(dayKey(day))
          : habit.checks.add(dayKey(day));
    });
    try {
      if (isWindowsDesktop) {
        await storage.setCheckIn(habit.id, dayKey(day), !previous);
      } else {
        await storage.save(habits);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          previous
              ? habit.checks.add(dayKey(day))
              : habit.checks.remove(dayKey(day));
        });
        localClock.refresh();
        message(
          'Check-in could not be saved. Only the current local day is editable.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changeAppearance(ThemeMode mode) async {
    try {
      await appearance.setMode(mode);
    } catch (_) {
      if (mounted) message('Could not save appearance. Please try again.');
    }
  }

  Future<void> init() async {
    try {
      await storage.open();
      final connection = isWindowsDesktop
          ? jsonDecode(await desktopRequest('cloudState'))
                as Map<String, dynamic>
          : <String, dynamic>{};
      final loaded = await storage.load();
      final tabs = await storage.loadMonths();
      if (!tabs.contains(month)) {
        tabs.add(month);
        tabs.sort();
        await storage.saveMonths(tabs);
      }
      if (mounted) {
        setState(() {
          habits = loaded;
          if (isWindowsDesktop) {
            cloud = connection;
            needsWelcome = connection['onboarded'] != true;
          }
          monthTabs = tabs;
          if (!tabs.contains(month)) month = tabs.last;
          loading = false;
          loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loadError = 'Your local database could not be opened. $e';
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    localClock.removeListener(onLocalDayChanged);
    localClock.dispose();
    cloudPoll?.cancel();
    searchController.dispose();
    storage.close();
    super.dispose();
  }

  DateTime get end => DateTime(month.year, month.month + 1, 0);
  DateTime get elapsedEnd => end.isBefore(now) ? end : now;
  List<Habit> get visible => habits
      .where(
        (h) =>
            (category == 'All habits' || h.category == category) &&
            h.name.toLowerCase().contains(query.toLowerCase()),
      )
      .toList();
  int get total =>
      habits.fold(0, (n, h) => n + h.opportunities(month, elapsedEnd));
  int get completed =>
      habits.fold(0, (n, h) => n + h.completions(month, elapsedEnd));
  double get rate => total == 0 ? 0 : completed / total;
  int get bestStreak => habits.fold(0, (n, h) => math.max(n, h.streak(now)));
  Future<void> persist(VoidCallback mutation) async {
    if (busy || loadError != null) return;
    final backup = habits.map((h) => Habit.fromJson(h.toJson())).toList();
    setState(() {
      busy = true;
      mutation();
    });
    try {
      await storage.save(habits);
    } catch (e) {
      if (mounted) {
        setState(() => habits = backup);
        message('Could not save. Your change was rolled back.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> selectMonth(DateTime selected) async {
    if (busy) return;
    final target = DateTime(selected.year, selected.month);
    if (!monthTabs.contains(target)) {
      final updated = [...monthTabs, target]..sort();
      try {
        await storage.saveMonths(updated);
        if (!mounted) return;
        setState(() => monthTabs = updated);
      } catch (e) {
        message('Could not save the new month. Please try again.');
        return;
      }
    }
    if (mounted) setState(() => month = target);
  }

  void changeMonth(int delta) {
    selectMonth(DateTime(month.year, month.month + delta));
  }

  Future<void> addMonth() async {
    final next = DateTime(monthTabs.last.year, monthTabs.last.month + 1);
    final chosen = await showDialog<DateTime>(
      context: context,
      builder: (_) => MonthDialog(initial: next),
    );
    if (chosen != null) await selectMonth(chosen);
  }

  Future<void> editHabit([Habit? existing]) async {
    final result = await showDialog<Habit>(
      context: context,
      builder: (_) => HabitDialog(existing: existing, now: now),
    );
    if (result != null) {
      await persist(() {
        if (existing == null) {
          habits.add(result);
        } else {
          habits[habits.indexOf(existing)] = result;
        }
      });
    }
  }

  Future<void> deleteHabit(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this habit?'),
        content: Text(
          '“${habit.name}” and its check-ins will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep habit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete habit'),
          ),
        ],
      ),
    );
    if (confirmed == true) await persist(() => habits.remove(habit));
  }

  Future<void> exportData() async {
    if (isWindowsDesktop) {
      try {
        final result = await desktopRequest('export');
        if (result == 'true') message('Backup exported.');
      } catch (e) {
        message('Could not export your backup. Please try another location.');
      }
      return;
    }
    final bytes = Uint8List.fromList(
      utf8.encode(
        JsonEncoder.withIndent('  ').convert({
          'format': 'trackverse',
          'version': 1,
          'habits': habits.map((h) => h.toJson()).toList(),
        }),
      ),
    );
    try {
      final location = await getSaveLocation(
        suggestedName: 'trackverse-${dayKey(now)}.json',
      );
      if (location != null) {
        await XFile.fromData(
          bytes,
          mimeType: 'application/json',
          name: 'trackverse.json',
        ).saveTo(location.path);
        message('Backup exported.');
      }
    } catch (e) {
      if (mounted) {
        await Clipboard.setData(ClipboardData(text: utf8.decode(bytes)));
        message('Backup copied to clipboard. Save it as a .json file.');
      }
    }
  }

  Future<void> importData() async {
    try {
      String content;
      if (isWindowsDesktop) {
        content = await desktopRequest('import');
        if (content == 'null') return;
      } else {
        final file = await openFile(
          acceptedTypeGroups: [
            XTypeGroup(label: 'TrackVerse backup', extensions: ['json']),
          ],
        );
        if (file == null) return;
        content = await file.readAsString();
      }
      final data = jsonDecode(content) as Map<String, dynamic>;
      if (data['format'] != 'trackverse' || data['version'] != 1) {
        throw FormatException();
      }
      final restored = (data['habits'] as List)
          .map((e) => Habit.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (restored.map((h) => h.id).toSet().length != restored.length ||
          restored.any(
            (h) =>
                h.name.trim().isEmpty ||
                h.color < 0 ||
                h.color >= habitColors.length ||
                h.icon < 0 ||
                h.icon >= habitIcons.length ||
                h.weekdays.isEmpty ||
                h.weekdays.any((d) => d < 1 || d > 7),
          )) {
        throw FormatException();
      }
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Restore backup?'),
          content: Text(
            'Replace your current habits with ${restored.length} habits from this backup? Export your current data first if you want to keep it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Restore'),
            ),
          ],
        ),
      );
      if (ok == true) {
        if (isWindowsDesktop) {
          final tabs =
              (jsonDecode(await desktopRequest('restore', jsonEncode(data)))
                      as List)
                  .map((m) => DateTime.parse(m as String))
                  .toList();
          await storage.load();
          if (mounted) {
            setState(() {
              habits = restored;
              monthTabs = tabs;
              if (!tabs.contains(month) && tabs.isNotEmpty) month = tabs.last;
            });
          }
          message('Backup restored.');
          return;
        }
        await persist(() => habits = restored);
      }
    } catch (e) {
      message('Unable to restore. Choose a valid TrackVerse JSON backup.');
    }
  }

  @override
  Widget build(BuildContext context) => needsWelcome
      ? WelcomeScreen(
          busy: cloudBusy,
          error: cloudError,
          onGoogle: () => cloudAction('googleSignIn', '', true),
          onLocal: () => cloudAction('cloudOnboarded', '', false),
          onCancel: () => desktopRequest('cancelGoogleSignIn'),
        )
      : LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1000;
            return Scaffold(
              body: Row(
                children: [
                  if (desktop) sidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        topbar(desktop),
                        Expanded(
                          child: loading
                              ? Center(child: CircularProgressIndicator())
                              : loadError != null
                              ? Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(loadError!),
                                        SizedBox(height: 16),
                                        FilledButton(
                                          onPressed: init,
                                          child: Text('Try again'),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  padding: EdgeInsets.all(desktop ? 34 : 18),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: 1600),
                                    child: page == 2
                                        ? settings()
                                        : content(desktop),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: desktop
                  ? null
                  : NavigationBar(
                      selectedIndex: page,
                      onDestinationSelected: (i) => setState(() => page = i),
                      destinations: [
                        NavigationDestination(
                          icon: Icon(Icons.grid_view_rounded),
                          label: 'Overview',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.insights_outlined),
                          label: 'Insights',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.settings_outlined),
                          label: 'Settings',
                        ),
                      ],
                    ),
            );
          },
        );
  Widget sidebar() => Container(
    width: 216,
    decoration: BoxDecoration(
      color: colors.surface,
      border: Border(right: BorderSide(color: line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(25, 33, 20, 38),
          child: Row(
            children: [
              brand(),
              SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TrackVerse',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 28, bottom: 13),
          child: Text(
            'WORKSPACE',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
        ),
        navItem(0, Icons.space_dashboard_outlined, 'Overview'),
        navItem(1, Icons.bar_chart_rounded, 'Insights'),
        SizedBox(height: 32),
        Padding(
          padding: EdgeInsets.only(left: 28, bottom: 16),
          child: Text(
            'YOUR SPACE',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 27),
          child: Row(
            children: [
              Icon(Icons.circle, size: 7, color: Color(0xFF57AA90)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Personal habits',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted),
                ),
              ),
              Text(
                '${habits.length}',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Spacer(),
        Padding(
          padding: EdgeInsets.all(18),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.raised,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.spa_outlined, color: purple, size: 24),
                SizedBox(height: 12),
                Text(
                  'Small steps.\nExtraordinary you.',
                  style: TextStyle(fontWeight: FontWeight.w600, height: 1.6),
                ),
                SizedBox(height: 7),
                Text(
                  'Build a little better, every day.',
                  style: TextStyle(color: muted, fontSize: 11, height: 1.6),
                ),
              ],
            ),
          ),
        ),
        navItem(2, Icons.settings_outlined, 'Settings'),
        Divider(height: 25),
        Padding(
          padding: EdgeInsets.fromLTRB(25, 0, 20, 25),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: colors.selected,
                child: Icon(Icons.person_outline, color: purple, size: 19),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My workspace',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Local account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more, size: 16, color: muted),
            ],
          ),
        ),
      ],
    ),
  );
  Widget brand() => Container(
    width: 31,
    height: 31,
    decoration: BoxDecoration(
      color: purple,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Icon(
      Icons.stacked_line_chart_rounded,
      color: Theme.of(context).colorScheme.onPrimary,
      size: 23,
    ),
  );
  Widget navItem(int index, IconData icon, String title) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 13, vertical: 3),
    child: Material(
      color: page == index ? colors.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => page = index),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 19, color: page == index ? purple : muted),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: page == index ? FontWeight.w600 : FontWeight.w400,
                  color: page == index ? purple : muted,
                ),
              ),
              if (page == index) ...[
                Spacer(),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: purple,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  Widget topbar(bool desktop) => Container(
    height: 75,
    padding: EdgeInsets.symmetric(horizontal: desktop ? 35 : 18),
    decoration: BoxDecoration(
      color: colors.surface,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        if (!desktop) ...[brand(), SizedBox(width: 10)],
        if (isWindowsDesktop)
          trackerSelector()
        else
          Text(
            desktop ? 'Workspace' : 'TrackVerse',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 13),
          child: Text('/', style: TextStyle(color: muted)),
        ),
        Text(
          ['Overview', 'Insights', 'Settings'][page],
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Spacer(),
        if (desktop)
          Text(
            'Make room for better habits.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        SizedBox(width: 20),
        IconButton(
          tooltip: colors.dark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () =>
              changeAppearance(colors.dark ? ThemeMode.light : ThemeMode.dark),
          icon: Icon(
            colors.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 19,
            color: muted,
          ),
        ),
        SizedBox(width: 10),
        Tooltip(
          message: (kIsWeb && !isWindowsDesktop)
              ? 'Browser preview · browser storage'
              : 'Private by design · saved in SQLite on this device',
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Color(0xFF69A28D)),
                if (desktop) ...[
                  SizedBox(width: 7),
                  Text(
                    (kIsWeb && !isWindowsDesktop)
                        ? 'Browser preview'
                        : 'Local & private',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Widget content(bool desktop) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A LITTLE BETTER, EVERY DAY',
                  style: TextStyle(
                    fontSize: 9,
                    color: purple,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 9),
                Text(
                  page == 1
                      ? 'Your progress, in perspective.'
                      : 'Consistency looks good on you.',
                  style: TextStyle(
                    fontSize: desktop ? 29 : 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.1,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 9),
                Text(
                  'Small actions add up. Here’s how your journey is taking shape.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (desktop) addButton(),
        ],
      ),
      SizedBox(height: 25),
      monthTabBar(),
      SizedBox(height: 20),
      Row(
        children: [
          monthPicker(),
          Spacer(),
          if (!desktop)
            addButton()
          else
            Text(
              '${habits.length} habits  ·  Your own pace',
              style: TextStyle(color: muted, fontSize: 11),
            ),
        ],
      ),
      SizedBox(height: 21),
      LayoutBuilder(
        builder: (context, c) => Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            stat(
              'Completion rate',
              '${(rate * 100).round()}%',
              'Of scheduled check-ins so far',
              Icons.donut_large,
              0,
              c.maxWidth,
            ),
            stat(
              'Total check-ins',
              '$completed',
              'Moments you showed up',
              Icons.check_circle_outline,
              1,
              c.maxWidth,
            ),
            stat(
              'Best current streak',
              '$bestStreak ${bestStreak == 1 ? 'day' : 'days'}',
              'Across your active habits',
              Icons.local_fire_department_outlined,
              2,
              c.maxWidth,
            ),
            stat(
              'Active habits',
              '${habits.length}',
              'Intentions turned into action',
              Icons.layers_outlined,
              3,
              c.maxWidth,
            ),
          ],
        ),
      ),
      SizedBox(height: 26),
      if (page == 0) ...[
        habitGrid(),
        SizedBox(height: 20),
        weeklySummary(),
        SizedBox(height: 24),
      ],
      LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 760;
          final chart = progressChart();
          final breakdown = progressBreakdown();
          return wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 16, child: chart),
                      SizedBox(width: 22),
                      Expanded(flex: 10, child: breakdown),
                    ],
                  ),
                )
              : Column(children: [chart, SizedBox(height: 18), breakdown]);
        },
      ),
      SizedBox(height: 23),
      Row(
        children: [
          Icon(Icons.lock_outline, size: 12, color: muted),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              (kIsWeb && !isWindowsDesktop)
                  ? 'Browser preview · Native builds store everything in SQLite on your device.'
                  : 'Your habits, your device. Everything is saved locally in SQLite.',
              style: TextStyle(fontSize: 10, color: muted),
            ),
          ),
          if (desktop)
            Text(
              'Progress over perfection.',
              style: TextStyle(fontSize: 10, color: muted),
            ),
        ],
      ),
      SizedBox(height: 10),
    ],
  );
  Widget addButton() => FilledButton.icon(
    onPressed: busy ? null : () => editHabit(),
    icon: Icon(Icons.add, size: 17),
    label: Text(
      'New habit',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
  Widget monthTabBar() => Container(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: monthTabs.map((m) {
                final selected = m == month;
                return Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => selectMonth(m),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(9),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? colors.selected : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: selected ? purple : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.table_chart_outlined,
                            size: 14,
                            color: selected ? purple : muted,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${months[m.month - 1].substring(0, 3)} ${m.year.toString().padLeft(4, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected ? purple : muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        IconButton(
          onPressed: busy ? null : addMonth,
          tooltip: 'Add month',
          icon: Icon(Icons.add_circle_outline, size: 21, color: purple),
        ),
      ],
    ),
  );
  Widget weeklySummary() => LayoutBuilder(
    builder: (context, c) {
      final count = (end.day / 7).ceil();
      final width = c.maxWidth > 850
          ? (c.maxWidth - 14 * (count - 1)) / count
          : (c.maxWidth - 14) / 2;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: List.generate(count, (i) {
          final start = DateTime(month.year, month.month, i * 7 + 1);
          final finish = DateTime(
            month.year,
            month.month,
            math.min((i + 1) * 7, end.day),
          );
          final cutoff = finish.isAfter(now) ? now : finish;
          final possible = habits.fold(
            0,
            (n, h) => n + h.opportunities(start, cutoff),
          );
          final done = habits.fold(
            0,
            (n, h) => n + h.completions(start, cutoff),
          );
          final r = possible == 0 ? 0.0 : done / possible;
          final color = weekColors[i % weekColors.length];
          return Container(
            width: width,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 7),
                    Text(
                      'WEEK ${i + 1}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .8,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${start.day}–${finish.day}',
                      style: TextStyle(fontSize: 9, color: muted),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          value: r,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          color: color,
                          backgroundColor: color.withValues(alpha: .1),
                        ),
                      ),
                      Text(
                        '${(r * 100).round()}%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 13),
                Text(
                  start.isAfter(now)
                      ? 'Up next'
                      : '$done of $possible check-ins',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          );
        }),
      );
    },
  );
  Widget monthPicker() => Container(
    decoration: BoxDecoration(
      color: colors.surface,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: () => changeMonth(-1),
          icon: Icon(Icons.chevron_left, size: 17),
        ),
        Icon(Icons.calendar_today_outlined, size: 13, color: purple),
        SizedBox(width: 9),
        Text(
          '${months[month.month - 1]} ${month.year}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: () => changeMonth(1),
          icon: Icon(Icons.chevron_right, size: 17),
        ),
      ],
    ),
  );
  Widget stat(
    String label,
    String value,
    String sub,
    IconData icon,
    int color,
    double width,
  ) {
    final col = habitColors[color];
    return Container(
      width: width > 850 ? (width - 48) / 4 : (width - 16) / 2,
      padding: EdgeInsets.all(20),
      decoration: box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ),
              Icon(icon, color: col, size: 17),
            ],
          ),
          SizedBox(height: 15),
          Text(
            value,
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: 8),
          Text(sub, style: TextStyle(color: muted, fontSize: 10)),
        ],
      ),
    );
  }

  BoxDecoration box() => BoxDecoration(
    color: colors.surface,
    borderRadius: BorderRadius.circular(13),
    border: Border.all(color: line),
  );
  Widget habitGrid() => Container(
    decoration: box(),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(23, 20, 17, 17),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 25,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Habit tracker',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 9),
                  pill('${visible.length} habits'),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 155,
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(color: line),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: (v) => setState(() => query = v),
                      style: TextStyle(fontSize: 11),
                      decoration: InputDecoration(
                        hintText: 'Find a habit…',
                        prefixIcon: Icon(Icons.search, size: 15),
                        prefixIconConstraints: BoxConstraints(minWidth: 30),
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  PopupMenuButton<String>(
                    tooltip: 'Filter by category',
                    initialValue: category,
                    onSelected: (v) => setState(() => category = v),
                    itemBuilder: (_) =>
                        ['All habits', ...habits.map((h) => h.category).toSet()]
                            .map((s) => PopupMenuItem(value: s, child: Text(s)))
                            .toList(),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: line),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.filter_list, size: 14, color: muted),
                          SizedBox(width: 7),
                          Text(category, style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (habits.isEmpty)
          emptyState()
        else if (visible.isEmpty)
          Padding(
            padding: EdgeInsets.all(35),
            child: Center(child: Text('No habits match your search.')),
          )
        else
          gridBody(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 23, vertical: 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: line)),
          ),
          child: Wrap(
            spacing: 22,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_outlined, size: 13, color: muted),
                  SizedBox(width: 6),
                  Text(
                    'Only today is editable. Past days are locked.',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
              legend(weekColors.first.withValues(alpha: .65), 'Completed'),
              legend(colors.border, 'Not completed'),
              Text(
                '—  Not scheduled / upcoming',
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget pill(String text) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: colors.raised,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(color: purple, fontSize: 9, fontWeight: FontWeight.w500),
    ),
  );
  Widget legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      SizedBox(width: 6),
      Text(label, style: TextStyle(color: muted, fontSize: 10)),
    ],
  );
  Widget emptyState() => Padding(
    padding: EdgeInsets.all(35),
    child: Center(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.raised,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.spa_outlined, color: purple, size: 30),
          ),
          SizedBox(height: 16),
          Text(
            'Your next chapter starts small.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Add your first habit and make a little space for yourself.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12),
          ),
          SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              addButton(),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => persist(() => habits = demoHabits(now)),
                child: Text(
                  'Explore with sample habits',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget gridBody() => TrackerGrid(
    habits: visible,
    month: month,
    now: now,
    busy: busy,
    onToggle: toggleCheckIn,
    onManage: (h, s) => s == 'edit' ? editHabit(h) : deleteHabit(h),
  );

  Widget progressChart() {
    final values = List.generate(end.day, (i) {
      final d = DateTime(month.year, month.month, i + 1);
      final scheduled = habits.where((h) => h.scheduled(d)).length;
      return d.isAfter(now) || scheduled == 0
          ? null
          : habits.where((h) => h.scheduled(d) && h.done(d)).length / scheduled;
    });
    return Container(
      padding: EdgeInsets.all(23),
      decoration: box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'The consistency curve',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              legend(purple, 'Daily completion'),
            ],
          ),
          SizedBox(height: 7),
          Text(
            'A little effort, a lasting difference.',
            style: TextStyle(color: muted, fontSize: 10),
          ),
          SizedBox(height: 25),
          SizedBox(
            height: 170,
            child: CustomPaint(
              painter: ProgressPainter(values, dark: colors.dark),
              size: Size.infinite,
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('01', style: TextStyle(color: muted, fontSize: 9)),
              Text(
                '${months[month.month - 1]} ${month.year}',
                style: TextStyle(color: muted, fontSize: 9),
              ),
              Text('${end.day}', style: TextStyle(color: muted, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget progressBreakdown() {
    final scheduled = habits.where((h) => h.scheduled(now)).length;
    final done = habits.where((h) => h.scheduled(now) && h.done(now)).length;
    return Container(
      padding: EdgeInsets.all(23),
      decoration: box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today, at a glance',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 7),
          Text(
            '${months[now.month - 1]} ${now.day} · One step at a time',
            style: TextStyle(color: muted, fontSize: 10),
          ),
          SizedBox(height: 22),
          Row(
            children: [
              SizedBox(
                width: 113,
                height: 113,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 105,
                      height: 105,
                      child: CircularProgressIndicator(
                        value: scheduled == 0 ? 0 : done / scheduled,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        backgroundColor: colors.selected,
                        color: purple,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$done/$scheduled',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'habits done',
                          style: TextStyle(fontSize: 9, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    legend(purple, '$done completed'),
                    SizedBox(height: 15),
                    legend(colors.selected, '${scheduled - done} to go'),
                    SizedBox(height: 18),
                    Text(
                      scheduled > 0 && done == scheduled
                          ? 'A full circle. Well done!'
                          : 'You’re building momentum.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: colors.raised,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '“Great things are done by a series of small things.”',
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Make yourself at home.',
        style: TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
      ),
      SizedBox(height: 8),
      Text(
        'Your space. Your habits. Your data.',
        style: TextStyle(color: muted),
      ),
      SizedBox(height: 28),
      if (isWindowsDesktop) ...[
        CloudPanel(
          state: cloud,
          busy: cloudBusy,
          action: cloudAction,
          onCreate: createTracker,
          onRename: renameTracker,
        ),
        SizedBox(height: 20),
      ],
      Container(
        padding: EdgeInsets.all(24),
        decoration: box(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Choose a comfortable space for your daily rituals.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            SizedBox(height: 18),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
              ],
              selected: {appearance.mode},
              onSelectionChanged: (values) => changeAppearance(values.first),
            ),
            SizedBox(height: 24),
            Divider(),
            SizedBox(height: 16),
            Text(
              'Local time & daily lock',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Your device sets the date. Only today can be marked or unmarked; past days stay locked. The app refreshes at midnight and when you return to it.',
              style: TextStyle(color: muted, height: 1.7),
            ),
          ],
        ),
      ),
      SizedBox(height: 20),
      Container(
        padding: EdgeInsets.all(25),
        decoration: box(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data & privacy',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              (kIsWeb && !isWindowsDesktop)
                  ? 'This browser preview uses browser storage. The Windows, Linux, and Android applications use a private SQLite database.'
                  : 'TrackVerse stores your habits and check-ins in a private SQLite database in your application support directory. No account, cloud service, or internet connection is required.',
              style: TextStyle(color: muted, height: 1.8),
            ),
            SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: exportData,
                  icon: Icon(Icons.download_outlined, size: 17),
                  label: Text('Export backup'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : importData,
                  icon: Icon(Icons.upload_outlined, size: 17),
                  label: Text('Restore backup'),
                ),
              ],
            ),
            SizedBox(height: 24),
            Divider(),
            SizedBox(height: 15),
            Text(
              'How progress is calculated',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 10),
            Text(
              'Completion rate = completed check-ins ÷ scheduled check-ins, from the start of the selected month through today. Future days and days before a habit was created are excluded. Streaks count consecutive scheduled days; an incomplete today does not break a streak until the day is over.',
              style: TextStyle(color: muted, height: 1.8),
            ),
            SizedBox(height: 24),
            Text(
              'TrackVerse 1.0.0',
              style: TextStyle(color: purple, fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );
}

class MonthDialog extends StatefulWidget {
  final DateTime initial;
  const MonthDialog({super.key, required this.initial});
  @override
  State<MonthDialog> createState() => _MonthDialogState();
}

class _MonthDialogState extends State<MonthDialog> {
  late int selectedMonth = widget.initial.month;
  late final year = TextEditingController(text: '${widget.initial.year}');
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('A fresh month. A fresh page.'),
    content: SizedBox(
      width: 340,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Habits carry forward. Check-ins stay with their dates.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<int>(
              initialValue: selectedMonth,
              decoration: const InputDecoration(labelText: 'Month'),
              items: List.generate(
                12,
                (i) => DropdownMenuItem(value: i + 1, child: Text(months[i])),
              ),
              onChanged: (v) => selectedMonth = v!,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: year,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(labelText: 'Year'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 1900 || n > 9999
                    ? 'Enter a year from 1900 to 9999.'
                    : null;
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              DateTime(int.parse(year.text), selectedMonth),
            );
          }
        },
        child: const Text('Add month'),
      ),
    ],
  );
}

class HabitDialog extends StatefulWidget {
  final Habit? existing;
  final DateTime now;
  const HabitDialog({super.key, this.existing, required this.now});
  @override
  State<HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<HabitDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name = TextEditingController(
    text: widget.existing?.name,
  );
  late String category = widget.existing?.category ?? 'Wellness';
  late int color = widget.existing?.color ?? 0,
      icon = widget.existing?.icon ?? 0;
  late Set<int> weekdays = {
    ...widget.existing?.weekdays ?? {1, 2, 3, 4, 5, 6, 7},
  };
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    title: Text(
      widget.existing == null
          ? 'Make space for a new habit.'
          : 'Refine your habit.',
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Start small. Make it yours.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: name,
                autofocus: true,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Habit name',
                  hintText: 'e.g. Read 20 pages',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Give your habit a name.'
                    : null,
              ),
              const SizedBox(height: 13),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items:
                    [
                          'Wellness',
                          'Learning',
                          'Mindfulness',
                          'Fitness',
                          'Creativity',
                          'Personal',
                        ]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              const SizedBox(height: 22),
              const Text(
                'Repeat on',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: List.generate(
                  7,
                  (i) => FilterChip(
                    label: Text(
                      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                      style: const TextStyle(fontSize: 10),
                    ),
                    showCheckmark: false,
                    selected: weekdays.contains(i + 1),
                    onSelected: (on) => setState(
                      () => on ? weekdays.add(i + 1) : weekdays.remove(i + 1),
                    ),
                  ),
                ),
              ),
              if (weekdays.isEmpty)
                const Text(
                  'Select at least one day.',
                  style: TextStyle(color: Colors.red, fontSize: 11),
                ),
              const SizedBox(height: 20),
              const Text(
                'Color & icon',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  habitColors.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => setState(() => color = i),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: habitColors[i],
                          shape: BoxShape.circle,
                        ),
                        child: color == i
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 17,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 5,
                children: List.generate(
                  habitIcons.length,
                  (i) => IconButton(
                    tooltip: 'Habit icon ${i + 1}',
                    onPressed: () => setState(() => icon = i),
                    style: IconButton.styleFrom(
                      backgroundColor: icon == i
                          ? habitColors[color].withValues(alpha: .15)
                          : Colors.transparent,
                    ),
                    icon: Icon(
                      habitIcons[i],
                      color: icon == i ? habitColors[color] : muted,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate() && weekdays.isNotEmpty) {
            Navigator.pop(
              context,
              Habit(
                id:
                    widget.existing?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.text.trim(),
                category: category,
                color: color,
                icon: icon,
                created: widget.existing?.created ?? widget.now,
                weekdays: weekdays,
                checks: widget.existing?.checks,
              ),
            );
          }
        },
        child: Text(widget.existing == null ? 'Create habit' : 'Save changes'),
      ),
    ],
  );
}

class ProgressPainter extends CustomPainter {
  final List<double?> values;
  final bool dark;
  ProgressPainter(this.values, {this.dark = false});
  @override
  void paint(Canvas canvas, Size size) {
    final left = 30.0, width = size.width - left, height = size.height - 10;
    final grid = Paint()
      ..color = dark ? const Color(0xFF32423B) : line
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = height * i / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      final t = TextPainter(
        text: TextSpan(
          text: '${100 - i * 25}%',
          style: const TextStyle(fontSize: 8, color: muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, Offset(0, y - 4));
    }
    final stroke = Paint()
      ..color = dark ? const Color(0xFF7AD5B0) : purple
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      if (values[i] == null) continue;
      points.add(
        Offset(
          left + width * i / (values.length - 1),
          height * (1 - values[i]!),
        ),
      );
    }
    if (points.isEmpty) return;
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(path)
      ..lineTo(points.last.dx, height)
      ..lineTo(points.first.dx, height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x3432816A), Color(0x0232816A)],
        ).createShader(Rect.fromLTWH(left, 0, width, height)),
    );
    canvas.drawPath(path, stroke);
    canvas.drawCircle(
      points.last,
      4,
      Paint()..color = dark ? const Color(0xFF7AD5B0) : purple,
    );
    canvas.drawCircle(
      points.last,
      2,
      Paint()..color = dark ? const Color(0xFF1B2523) : Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant ProgressPainter oldDelegate) => true;
}
