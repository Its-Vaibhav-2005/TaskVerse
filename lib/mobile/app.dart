import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../appearance.dart';
import '../app_version.dart';
import '../model.dart';
import 'controller.dart';
import 'consistency_header.dart';

const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _monthNames = [
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

class MobileApp extends StatefulWidget {
  final MobileController? controller;
  const MobileApp({super.key, this.controller});
  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> with WidgetsBindingObserver {
  late final c = widget.controller ?? MobileController();
  int tab = 0;
  bool showAll = false;
  String filter = 'All';
  late DateTime selectedDay = dayOnly(DateTime.now());
  Timer? clock;
  DateTime get today => dayOnly(DateTime.now());
  AppPalette get palette => AppPalette(context);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(changed);
    if (widget.controller == null) unawaited(c.initialize());
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      unawaited(c.syncAll());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clock?.cancel();
    c.removeListener(changed);
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  List<Habit> get scheduled =>
      c.habits.where((h) => h.scheduled(today)).toList();
  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.done_all_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'TrackVerse',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: c.loading ? null : settings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: c.loading
            ? const Center(child: CircularProgressIndicator())
            : c.active == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    c.error ??
                        'Unable to open local storage. Restart TrackVerse.',
                  ),
                ),
              )
            : Column(
                children: [
                  if (MobileController.preview)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'PREVIEW · SAMPLE DATA',
                        style: TextStyle(fontSize: 10, letterSpacing: 1.5),
                      ),
                    ),
                  if (c.busy) const LinearProgressIndicator(minHeight: 2),
                  if (c.error != null)
                    MaterialBanner(
                      content: Text(
                        c.error!,
                        style: const TextStyle(fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            c.error = null;
                            changed();
                          },
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: tab,
                      children: [
                        todayPage(),
                        progressPage(),
                        MobileFocus(key: ValueKey(c.active!.id), controller: c),
                        syncPage(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton:
          tab == 0 && !c.loading && c.active != null && c.habits.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: c.busy ? null : () => editHabit(),
              icon: const Icon(Icons.add),
              label: const Text('New habit'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.timelapse_outlined),
            selectedIcon: Icon(Icons.timelapse_rounded),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud_rounded),
            label: 'Sync',
          ),
        ],
      ),
    );
  }

  Widget panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
    Color? color,
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      border: Border.all(color: palette.border),
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
  Widget heading(String eyebrow, String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.8,
          color: palette.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: TextStyle(fontSize: 14, color: palette.muted, height: 1.5),
      ),
    ],
  );
  Widget todayPage() {
    final list = scheduled, done = list.where((h) => h.done(today)).length;
    final shown = (showAll ? c.habits : list)
        .where((h) => filter == 'All' || h.category == filter)
        .toList();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    return RefreshIndicator(
      onRefresh: () => c.syncAll(),
      child: ListView(
        key: const PageStorageKey('today'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          ConsistencyHeader(
            habits: c.habits,
            today: today,
            accent: palette.accent,
            background: palette.background,
            child: heading(
              '${_monthNames[today.month - 1]} ${today.day} · ${today.year}',
              'Small steps.\nBetter days.',
              'Make a little room for what matters.',
            ),
          ),
          const SizedBox(height: 22),
          panel(
            color: palette.accent.withValues(alpha: 0.09),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.isNotEmpty && done == list.length
                            ? 'A day well spent.'
                            : 'Your daily rhythm',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$done of ${list.length} habits complete',
                        style: TextStyle(color: palette.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Consistency starts with today.',
                        style: TextStyle(color: palette.accent, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: list.isEmpty ? 0 : done / list.length,
                          strokeWidth: 7,
                          backgroundColor: palette.accent.withValues(
                            alpha: .12,
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        '${list.isEmpty ? 0 : (100 * done / list.length).round()}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = weekStart.add(Duration(days: i)),
                  current = day == today;
              final dayHabits = c.habits
                  .where((h) => h.scheduled(day))
                  .toList();
              final complete =
                  dayHabits.isNotEmpty && dayHabits.every((h) => h.done(day));
              return Expanded(
                child: Semantics(
                  label: '${dayKey(day)}${current ? ', today' : ''}',
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: current ? palette.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weekdays[i],
                          style: TextStyle(
                            fontSize: 11,
                            color: current ? Colors.white70 : palette.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: current ? Colors.white : palette.text,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Icon(
                          complete ? Icons.check_circle : Icons.circle,
                          size: 6,
                          color: current
                              ? Colors.white
                              : complete
                              ? palette.accent
                              : palette.border,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  showAll ? 'Your habits' : 'Today’s habits',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => showAll = !showAll),
                child: Text(showAll ? 'Today only' : 'See all'),
              ),
            ],
          ),
          if (c.habits.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', ...c.habits.map((h) => h.category).toSet()]
                    .map(
                      (name) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(name),
                          selected: filter == name,
                          onSelected: (_) => setState(() => filter = name),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            panel(
              child: Column(
                children: [
                  Icon(Icons.spa_outlined, size: 38, color: palette.accent),
                  const SizedBox(height: 14),
                  Text(
                    c.habits.isEmpty
                        ? 'Start with one small habit'
                        : 'A little breathing room',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.habits.isEmpty
                        ? 'Read a page. Drink a glass of water.\nChoose something that feels like you.'
                        : 'No habits match this view. Try See all.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.muted, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  if (c.habits.isEmpty)
                    FilledButton(
                      onPressed: c.busy ? null : () => editHabit(),
                      child: const Text('Create your first habit'),
                    ),
                ],
              ),
            ),
          ...shown.map(habitCard),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                c.active!.sheetId == null
                    ? Icons.phone_android
                    : Icons.cloud_done_outlined,
                size: 14,
                color: palette.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  c.active!.sheetId == null
                      ? 'Saved on this device · Connect Google in Sync'
                      : c.syncLabel,
                  style: TextStyle(color: palette.muted, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget habitCard(Habit h) {
    final color = habitColors[h.color],
        done = h.done(today),
        enabled = h.scheduled(today);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: panel(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(habitIcons[h.icon], color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: c.busy ? null : () => editHabit(h),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? palette.muted : palette.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        enabled
                            ? '${h.category} · ${h.streak(today)} day streak'
                            : '${h.category} · Not scheduled today',
                        style: TextStyle(color: palette.muted, fontSize: 11),
                      ),
                      if (h.dailyTarget > 1) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: h.countOn(today) / h.dailyTarget,
                          minHeight: 3,
                          color: color,
                          backgroundColor: color.withValues(alpha: .1),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (h.dailyTarget == 1)
              IconButton(
                tooltip: done ? 'Undo ${h.name}' : 'Complete ${h.name}',
                onPressed: c.busy || !enabled
                    ? null
                    : () => c.setCount(h.id, done ? 0 : 1),
                icon: Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 30,
                  color: done ? color : palette.muted,
                ),
              )
            else
              Column(
                children: [
                  IconButton(
                    tooltip: 'Add progress to ${h.name}',
                    onPressed: c.busy || !enabled ? null : () => countSheet(h),
                    icon: Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline,
                      color: color,
                      size: 29,
                    ),
                  ),
                  Text(
                    '${h.countOn(today)}/${h.dailyTarget}',
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> countSheet(Habit h) async {
    c.editing = true;
    var count = h.countOn(today);
    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    h.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Today’s progress · goal ${h.dailyTarget}'),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Decrease count',
                        onPressed: count == 0
                            ? null
                            : () => update(() => count--),
                        icon: const Icon(Icons.remove),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Increase count',
                        onPressed: count == h.dailyTarget
                            ? null
                            : () => update(() => count++),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, count),
                      child: const Text('Save progress'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result != null) await c.setCount(h.id, result);
    c.editing = false;
  }

  Widget progressPage() {
    final month = DateTime(selectedDay.year, selectedDay.month);
    final end = DateTime(month.year, month.month + 1, 0),
        cutoff = end.isAfter(today) ? today : end;
    final opportunities = c.habits.fold<int>(
      0,
      (n, h) => n + h.opportunities(month, cutoff),
    );
    final completions = c.habits.fold<int>(
      0,
      (n, h) => n + h.completions(month, cutoff),
    );
    final streak = c.habits.fold<int>(
      0,
      (n, h) => math.max(n, h.streak(today)),
    );
    final history = c.habits.where((h) => h.scheduled(selectedDay)).toList();
    return ListView(
      key: const PageStorageKey('progress'),
      padding: const EdgeInsets.all(20),
      children: [
        heading(
          'The bigger picture',
          'Look how far\nyou’ve come.',
          'Every check-in adds up. Keep your own pace.',
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_graph_rounded, color: palette.accent),
                    const SizedBox(height: 12),
                    Text(
                      '${opportunities == 0 ? 0 : (completions * 100 / opportunities).round()}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Month completion',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      color: habitColors[2],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$streak days',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Best current streak',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        panel(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => setState(
                      () => selectedDay = DateTime(month.year, month.month - 1),
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthNames[month.month - 1]} ${month.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => setState(
                      () => selectedDay = DateTime(month.year, month.month + 1),
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: _weekdays
                    .map(
                      (d) => Expanded(
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.muted, fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                ),
                itemCount: month.weekday - 1 + end.day,
                itemBuilder: (ctx, index) {
                  final day = index - (month.weekday - 1) + 1;
                  if (day < 1) return const SizedBox.shrink();
                  final date = DateTime(month.year, month.month, day);
                  final habits = c.habits
                      .where((h) => h.scheduled(date))
                      .toList();
                  final count = habits.where((h) => h.done(date)).length;
                  final selected = date == selectedDay;
                  return Semantics(
                    label:
                        '${dayKey(date)}, $count of ${habits.length} complete',
                    child: InkWell(
                      onTap: () => setState(() => selectedDay = date),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: selected
                              ? palette.accent
                              : count > 0
                              ? palette.accent.withValues(
                                  alpha: .1 + .5 * count / habits.length,
                                )
                              : palette.background,
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: selected ? Colors.white : palette.text,
                            fontWeight: date == today
                                ? FontWeight.w800
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Text(
                '$completions check-ins this month',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '${_monthNames[selectedDay.month - 1]} ${selectedDay.day}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'History is read-only. Check in from Today.',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (history.isEmpty) const Text('No habits scheduled for this day.'),
        ...history.map(
          (h) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(habitIcons[h.icon], color: habitColors[h.color]),
            title: Text(h.name),
            subtitle: Text('${h.countOn(selectedDay)} / ${h.dailyTarget}'),
            trailing: Icon(
              h.done(selectedDay) ? Icons.check_circle : Icons.circle_outlined,
              color: h.done(selectedDay) ? palette.accent : palette.muted,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget syncPage() {
    final connected = c.google.connected, w = c.active!;
    final last = DateTime.tryParse(
      w.sync['lastSync'] as String? ?? '',
    )?.toLocal();
    return ListView(
      key: const PageStorageKey('sync'),
      padding: const EdgeInsets.all(20),
      children: [
        heading(
          'Your habits, everywhere',
          'One rhythm.\nEvery device.',
          'Keep your phone and desktop in step with private Google Sheets backups.',
        ),
        const SizedBox(height: 24),
        panel(
          color: palette.accent.withValues(alpha: .08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                connected ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                size: 36,
                color: palette.accent,
              ),
              const SizedBox(height: 16),
              Text(
                connected ? 'Connected to Google' : 'Your data stays yours.',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                connected
                    ? c.google.email!
                    : 'Everything works locally. Connect Google to pick up where you left off on another device.',
                style: TextStyle(color: palette.muted, height: 1.6),
              ),
              const SizedBox(height: 18),
              if (!connected)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: c.busy || !c.google.configured
                        ? null
                        : () => c.connect(),
                    icon: const Icon(Icons.login),
                    label: const Text('Connect Google'),
                  ),
                ),
              if (!c.google.configured) ...[
                const SizedBox(height: 10),
                const Text(
                  'Google connection will be available after the Android sign-in setup is completed. Local tracking and file backups are ready to use.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ],
              if (connected)
                OutlinedButton(
                  onPressed: c.busy ? null : () => c.disconnect(),
                  child: const Text('Disconnect Google'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THIS TRACKER',
                style: TextStyle(fontSize: 10, letterSpacing: 1.6),
              ),
              const SizedBox(height: 10),
              Text(
                w.alias,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                w.sheetId == null ? 'Saved on this device' : c.syncLabel,
                style: TextStyle(color: palette.accent),
              ),
              if (last != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Last synced ${last.day}/${last.month} at ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                ),
              const SizedBox(height: 18),
              if (connected && w.sheetId == null)
                FilledButton.icon(
                  onPressed: c.busy ? null : () => c.linkNew(),
                  icon: const Icon(Icons.add_to_drive_outlined),
                  label: const Text('Back up this tracker'),
                ),
              if (connected && w.sheetId != null)
                FilledButton.icon(
                  onPressed: c.busy ? null : () => c.sync(),
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync now'),
                ),
              if (c.conflict) ...[
                const SizedBox(height: 16),
                const Text(
                  'This tracker changed on more than one device. Choose the version to continue with. Both histories are retained.',
                  style: TextStyle(height: 1.6),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: c.busy ? null : () => resolve('remote'),
                      child: const Text('Use Google version'),
                    ),
                    OutlinedButton(
                      onPressed: c.busy ? null : () => resolve('local'),
                      child: const Text('Keep this device'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (connected)
          OutlinedButton.icon(
            onPressed: c.busy ? null : discover,
            icon: const Icon(Icons.travel_explore),
            label: const Text('Find my trackers'),
          ),
        if (c.workspaces.length > 1) ...[
          const SizedBox(height: 20),
          const Text(
            'Your trackers',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          ...c.workspaces.map(
            (item) => ListTile(
              title: Text(item.alias),
              subtitle: Text(
                item.sheetId == null ? 'On this device' : 'Google Sheets',
              ),
              trailing: Icon(
                item.id == w.id ? Icons.check_circle : Icons.circle_outlined,
              ),
              onTap: c.busy ? null : () => c.select(item.id),
            ),
          ),
        ],
        const SizedBox(height: 24),
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pick up on another device',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                '1. Back up your tracker on the first device.\n2. Connect the same Google account here.\n3. Tap Find my trackers and open it.\n\nSync runs while TrackVerse is open and when you return. Offline changes stay on your device until a successful sync.',
                style: TextStyle(
                  color: palette.muted,
                  height: 1.7,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> resolve(String version) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Continue with this version?'),
        content: Text(
          version == 'remote'
              ? 'Use the Google version on this device? Your current data will be kept in local recovery history.'
              : 'Publish this device’s version as the next backup? Previous Google versions remain in history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (yes == true) await c.sync(resolve: version);
  }

  Future<void> discover() async {
    final files = await c.discover();
    if (!mounted || c.error != null) return;
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text(
              'Your Google trackers',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            if (files.isEmpty)
              const Text(
                'No trackers found. Back up a tracker from your other device using the same Google account.',
              ),
            ...files.map(
              (f) => ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: Text(
                  f['appProperties']?['alias'] as String? ??
                      f['name'] as String,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(ctx, f['id'] as String),
              ),
            ),
          ],
        ),
      ),
    );
    if (id != null) await c.openRemote(id);
  }

  Future<void> editHabit([Habit? habit]) async {
    c.editing = true;
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MobileHabitEditor(habit: habit),
    );
    if (result is Habit) await c.saveHabit(result);
    if (result == 'delete' && habit != null) await c.deleteHabit(habit.id);
    c.editing = false;
  }

  Future<void> exportBackup() async {
    final bytes = Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(c.active!.snapshot),
      ),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/json')],
        fileNameOverrides: ['TrackVerse-${dayKey(today)}.json'],
      ),
    );
  }

  Future<void> importBackup() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'TrackVerse backup',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 8 * 1024 * 1024) {
      c.error = 'Backup exceeds 8 MB.';
      changed();
      return;
    }
    await c.importBackup(await file.readAsString());
  }

  Future<void> recovery() async {
    final rows = await c.store.recovery(c.active!.id);
    if (!mounted) return;
    final id = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Local recovery history',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            const Text('Open a previous local version as a separate tracker.'),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'No replacements yet. Versions are saved here before applying Google updates.',
                ),
              ),
            ...rows.map(
              (r) => ListTile(
                title: Text(
                  (r['saved'] as String)
                      .replaceFirst('T', ' ')
                      .split('.')
                      .first,
                ),
                trailing: const Icon(Icons.restore),
                onTap: () => Navigator.pop(ctx, r['id'] as int),
              ),
            ),
          ],
        ),
      ),
    );
    if (id != null) await c.restoreRecovery(id);
  }

  Future<void> settings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Make it your own',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_box_outlined),
                title: const Text('Create tracker'),
                subtitle: const Text(
                  'Keep work, personal and other habits separate',
                ),
                onTap: c.busy
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await createTracker();
                      },
              ),
              ...c.workspaces.map(
                (w) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(w.alias),
                  subtitle: Text(
                    w.sheetId == null ? 'On this device' : 'Google Sheets',
                  ),
                  trailing: w.id == c.active?.id
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: c.busy
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await c.select(w.id);
                        },
                ),
              ),
              const Divider(),
              const Text('Appearance'),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (ctx, update) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ThemeMode.values
                      .map(
                        (mode) => ChoiceChip(
                          label: Text(switch (mode) {
                            ThemeMode.system => 'System',
                            ThemeMode.light => 'Light',
                            ThemeMode.dark => 'Dark',
                          }),
                          selected: appearance.mode == mode,
                          onSelected: (_) async {
                            await appearance.setMode(mode);
                            if (ctx.mounted) update(() {});
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme color'),
                subtitle: Text(appearance.presetName),
                onTap: () async {
                  Navigator.pop(ctx);
                  await themePicker();
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('Export backup'),
                subtitle: const Text('Save or share a portable JSON file'),
                onTap: c.busy
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await exportBackup();
                      },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_open_outlined),
                title: const Text('Import backup'),
                subtitle: const Text('Open as a separate tracker'),
                onTap: c.busy
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await importBackup();
                      },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: const Text('Local recovery history'),
                onTap: c.busy
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await recovery();
                      },
              ),
              const SizedBox(height: 16),
              Text(
                '$appVersionLabel · Your habits, your pace.\nLocal first. No ads. No tracking.',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> createTracker() async {
    final name = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create tracker'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: name,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Tracker name',
              hintText: 'e.g. Work or Personal',
            ),
            validator: (s) => s == null || s.trim().isEmpty
                ? 'Give your tracker a name.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
                if (form.currentState!.validate()) {
                Navigator.pop(ctx, name.text.trim());
                }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    // The dialog's exit animation may still reference its text controller.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 400), name.dispose),
    );
    if (result == null || !mounted) return;
    await c.createTracker(result);
    if (!mounted || c.error != null) return;
    setState(() {
      tab = 0;
      filter = 'All';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tracker created. Use Sync → Back up this tracker to use it on other devices.',
        ),
      ),
    );
  }

  Future<void> themePicker() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose your atmosphere',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...themePresets.map(
            (preset) => ListTile(
              title: Text(preset.name),
              trailing: appearance.presetName == preset.name
                  ? const Icon(Icons.check)
                  : null,
              onTap: () async {
                await appearance.setPreset(preset.name);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class MobileHabitEditor extends StatefulWidget {
  final Habit? habit;
  const MobileHabitEditor({super.key, this.habit});
  @override
  State<MobileHabitEditor> createState() => _MobileHabitEditorState();
}

class _MobileHabitEditorState extends State<MobileHabitEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.habit?.name);
  late String category = widget.habit?.category ?? 'Wellness';
  late int color = widget.habit?.color ?? 1,
      icon = widget.habit?.icon ?? 0,
      target = widget.habit?.dailyTarget ?? 1;
  late Set<int> weekdays = {...?widget.habit?.weekdays};
  late bool allMonths = widget.habit?.months == null;
  @override
  void initState() {
    super.initState();
    if (widget.habit == null) weekdays = {1, 2, 3, 4, 5, 6, 7};
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.habit == null
                  ? 'A small promise to yourself.'
                  : 'Make this habit yours.',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: name,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Habit name',
                hintText: 'e.g. Read for 20 minutes',
                border: OutlineInputBorder(),
              ),
              validator: (s) => s == null || s.trim().isEmpty
                  ? 'Give your habit a name.'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: habitCategories
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (s) => setState(() => category = s!),
            ),
            const SizedBox(height: 24),
            const Text(
              'Repeat on',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Continue across all months'),
              subtitle: const Text('Keep this habit in your future plans'),
              value: allMonths,
              onChanged: (value) => setState(() => allMonths = value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(
                7,
                (i) => FilterChip(
                  label: Text(
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                  ),
                  selected: weekdays.contains(i + 1),
                  onSelected: (v) => setState(() {
                    if (v) {
                      weekdays.add(i + 1);
                    } else if (weekdays.length > 1) {
                      weekdays.remove(i + 1);
                    }
                  }),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Daily target',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Decrease target',
                  onPressed: target > 1 ? () => setState(() => target--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$target', style: const TextStyle(fontSize: 20)),
                IconButton(
                  tooltip: 'Increase target',
                  onPressed: target < 99
                      ? () => setState(() => target++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(
                habitColors.length,
                (i) => IconButton(
                  tooltip: 'Color ${i + 1}',
                  onPressed: () => setState(() => color = i),
                  icon: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: habitColors[i],
                      shape: BoxShape.circle,
                    ),
                    child: i == color
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(
                habitIcons.length,
                (i) => IconButton.filledTonal(
                  tooltip: habitIconNames[i],
                  isSelected: i == icon,
                  style: IconButton.styleFrom(
                    backgroundColor: i == icon
                        ? habitColors[color].withValues(alpha: .2)
                        : Colors.transparent,
                  ),
                  onPressed: () => setState(() => icon = i),
                  icon: Icon(
                    habitIcons[i],
                    color: i == icon ? habitColors[color] : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  final h = widget.habit;
                  Navigator.pop(
                    context,
                    Habit(
                      id: h?.id ?? const Uuid().v4(),
                      name: name.text.trim(),
                      category: category,
                      color: color,
                      icon: icon,
                      created: h?.created ?? DateTime.now(),
                      weekdays: weekdays,
                      checks: {...?h?.checks},
                      months: allMonths
                          ? null
                          : h?.months ?? {monthKey(DateTime.now())},
                      dailyTarget: target,
                      dailyCounts: {...?h?.dailyCounts},
                      reminder: h?.reminder,
                    ),
                  );
                },
                child: Text(
                  widget.habit == null ? 'Create habit' : 'Save changes',
                ),
              ),
            ),
            if (widget.habit != null)
              Center(
                child: TextButton(
                  onPressed: () async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete this habit?'),
                        content: const Text(
                          'Its check-ins will be removed from this tracker. Recorded focus sessions remain.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (yes == true && context.mounted) {
                      Navigator.pop(context, 'delete');
                    }
                  },
                  child: const Text('Delete habit'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class MobileFocus extends StatefulWidget {
  final MobileController controller;
  const MobileFocus({super.key, required this.controller});
  @override
  State<MobileFocus> createState() => _MobileFocusState();
}

class _MobileFocusState extends State<MobileFocus>
    with AutomaticKeepAliveClientMixin {
  String? habitId;
  int duration = 25, elapsed = 0;
  DateTime? started, runningSince;
  Timer? ticker;
  bool saving = false, restoring = true;
  String? sessionId;
  late final workspaceId = widget.controller.active!.id;
  @override
  void initState() {
    super.initState();
    unawaited(restoreDraft());
  }

  Future<void> restoreDraft() async {
    try {
      final draft = await widget.controller.store.focusDraft(workspaceId);
      if (!mounted) return;
      if (draft != null) {
        habitId = draft['habitId'] as String;
        sessionId = draft['id'] as String;
        duration = (draft['duration'] as int).clamp(1, 180);
        elapsed = (draft['elapsed'] as int).clamp(0, duration * 60);
        started = DateTime.parse(draft['started'] as String);
        runningSince = draft['runningSince'] == null
            ? null
            : DateTime.parse(draft['runningSince'] as String);
        if (runningSince != null) startTicker();
      }
    } catch (_) {
      /* A corrupt timer draft never prevents habit tracking. */
    }
    if (mounted) setState(() => restoring = false);
  }

  Future<void> persistDraft() async {
    try {
      await widget.controller.store.saveFocusDraft(
        workspaceId,
        started == null
            ? null
            : {
                'id': sessionId,
                'habitId': habitId,
                'duration': duration,
                'elapsed': elapsed,
                'started': started!.toIso8601String(),
                'runningSince': runningSince?.toIso8601String(),
              },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save the timer state. Finish and save before closing the app.',
            ),
          ),
        );
      }
    }
  }

  int get seconds =>
      (elapsed +
              (runningSince == null
                  ? 0
                  : DateTime.now().difference(runningSince!).inSeconds))
          .clamp(0, duration * 60);
  @override
  bool get wantKeepAlive => true;
  void startPause() {
    if (runningSince != null) {
      elapsed = seconds;
      runningSince = null;
      ticker?.cancel();
      unawaited(persistDraft());
      setState(() {});
      return;
    }
    started ??= DateTime.now();
    sessionId ??= const Uuid().v4();
    runningSince = DateTime.now();
    unawaited(persistDraft());
    startTicker();
    setState(() {});
  }

  void startTicker() {
    ticker?.cancel();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (seconds >= duration * 60) {
        unawaited(save());
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> save() async {
    if (saving ||
        widget.controller.busy ||
        widget.controller.active!.id != workspaceId) {
      return;
    }
    final habit = widget.controller.habits
        .where((h) => h.id == habitId)
        .firstOrNull;
    if (habit == null || started == null) return;
    final captured = seconds;
    elapsed = captured;
    runningSince = null;
    ticker?.cancel();
    setState(() => saving = true);
    await widget.controller.saveFocus({
      'id': sessionId ??= const Uuid().v4(),
      'habitId': habit.id,
      'name': habit.name,
      'color': habit.color,
      'seconds': captured,
      'started': started!.toUtc().toIso8601String(),
    });
    if (!mounted) return;
    if (widget.controller.error == null) {
      elapsed = 0;
      started = null;
      sessionId = null;
      await persistDraft();
    }
    if (!mounted) return;
    setState(() => saving = false);
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = widget.controller,
        p = AppPalette(context),
        remaining = duration * 60 - seconds;
    final habits = c.habits;
    final selected = habits.any((h) => h.id == habitId) ? habitId : null;
    final sessions = c.active!.snapshot['focusSessions'] as List;
    final todayMinutes =
        sessions
            .where(
              (s) =>
                  dayOnly(DateTime.parse(s['started']).toLocal()) ==
                  dayOnly(DateTime.now()),
            )
            .fold<num>(0, (n, s) => n + s['seconds']) ~/
        60;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Text(
          'A MOMENT OF FOCUS',
          style: TextStyle(
            color: p.accent,
            letterSpacing: 1.7,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'One thing\nat a time.',
          style: TextStyle(
            fontSize: 32,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Give a little time to something that matters.',
          style: TextStyle(color: p.muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          decoration: const InputDecoration(
            labelText: 'Focus on a habit',
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
          items: habits
              .map(
                (h) => DropdownMenuItem(
                  value: h.id,
                  child: Text(h.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: started != null || restoring
              ? null
              : (s) => setState(() => habitId = s),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: seconds / (duration * 60),
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: p.accent.withValues(alpha: .12),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 180,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      runningSince == null
                          ? 'A little space to begin'
                          : 'You’re right where you need to be',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.muted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          children: [15, 25, 45]
              .map(
                (m) => ChoiceChip(
                  label: Text('$m min'),
                  selected: duration == m,
                  onSelected: started != null
                      ? null
                      : (_) => setState(() => duration = m),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: selected == null || saving || restoring || c.busy
              ? null
              : startPause,
          icon: Icon(runningSince == null ? Icons.play_arrow : Icons.pause),
          label: Text(runningSince == null ? 'Start focus' : 'Pause focus'),
        ),
        if (started != null)
          TextButton(
            onPressed: saving || c.busy ? null : save,
            child: const Text('Finish and save time'),
          ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '$todayMinutes minutes invested today',
            style: TextStyle(color: p.accent, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your timer is saved on this device, even if you switch tabs or restart. Background alerts are not enabled.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: p.muted, height: 1.5),
        ),
      ],
    );
  }
}
