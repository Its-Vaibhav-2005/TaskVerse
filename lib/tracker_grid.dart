import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'model.dart';
import 'appearance.dart';
import 'local_clock.dart';

const _weeks = [
  Color(0xFF58A28B),
  Color(0xFF9980C6),
  Color(0xFFD08D83),
  Color(0xFFD4A359),
  Color(0xFF8E9CA8),
];

class TrackerGrid extends StatefulWidget {
  final List<Habit> habits;
  final DateTime month, now;
  final bool busy;
  final void Function(Habit, DateTime) onToggle;
  final void Function(Habit, String) onManage;
  const TrackerGrid({
    super.key,
    required this.habits,
    required this.month,
    required this.now,
    required this.busy,
    required this.onToggle,
    required this.onManage,
  });
  @override
  State<TrackerGrid> createState() => _TrackerGridState();
}

class _TrackerGridState extends State<TrackerGrid> {
  AppPalette get colors => AppPalette(context);
  Color get _border => colors.border;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  int get length => DateTime(widget.month.year, widget.month.month + 1, 0).day;
  DateTime date(int i) =>
      DateTime(widget.month.year, widget.month.month, i + 1);
  DateTime get cutoff {
    final end = date(length - 1);
    return end.isBefore(widget.now) ? end : widget.now;
  }

  BoxDecoration cellDecoration({Color? color, bool right = false}) =>
      BoxDecoration(
        color: color ?? colors.surface,
        border: Border(
          bottom: BorderSide(color: _border),
          right: BorderSide(color: right ? _border : Colors.transparent),
        ),
      );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final pinned = c.maxWidth > 600 ? 210.0 : 154.0;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: pinned,
            child: Column(
              children: [
                Container(
                  height: 150,
                  padding: EdgeInsets.all(14),
                  alignment: Alignment.bottomLeft,
                  decoration: cellDecoration(color: colors.raised, right: true),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR DAILY RITUALS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8,
                          color: colors.muted,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Habits',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Show up for yourself.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: colors.muted),
                      ),
                    ],
                  ),
                ),
                ...widget.habits.map(
                  (h) => Container(
                    height: 62,
                    padding: EdgeInsets.only(left: 14, right: 3),
                    decoration: cellDecoration(right: true),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: habitColors[h.color].withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            habitIcons[h.icon],
                            size: 15,
                            color: habitColors[h.color],
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                h.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 22,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            tooltip: 'Manage ${h.name}',
                            icon: Icon(
                              Icons.more_horiz,
                              size: 15,
                              color: colors.muted,
                            ),
                            onSelected: (v) => widget.onManage(h, v),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit habit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete habit'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: scroll,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(bottom: 9),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ...List.generate((length / 7).ceil(), (week) {
                          final count = math.min(7, length - week * 7),
                              color = _weeks[week];
                          return SizedBox(
                            width: count * 36,
                            child: Column(
                              children: [
                                Container(
                                  height: 25,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: .2),
                                    border: Border(
                                      right: BorderSide(
                                        color: color.withValues(alpha: .2),
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'WEEK ${week + 1}',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: List.generate(
                                    count,
                                    (offset) =>
                                        dayHeader(week * 7 + offset, color),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        summaryHeader('PROGRESS', 85),
                        summaryHeader('STREAK', 65),
                      ],
                    ),
                    ...widget.habits.map(
                      (h) => Row(
                        children: [
                          ...List.generate(length, (i) => checkCell(h, i)),
                          Container(
                            width: 85,
                            height: 62,
                            padding: EdgeInsets.symmetric(horizontal: 13),
                            decoration: cellDecoration(right: true),
                            child: Builder(
                              builder: (_) {
                                final den = h.opportunities(
                                  widget.month,
                                  cutoff,
                                );
                                final rate = den == 0
                                    ? 0.0
                                    : h.completions(widget.month, cutoff) / den;
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${(rate * 100).round()}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 7),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: rate,
                                        minHeight: 4,
                                        color: colors.accent,
                                        backgroundColor: _border,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          Container(
                            width: 65,
                            height: 62,
                            alignment: Alignment.center,
                            decoration: cellDecoration(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_fire_department_outlined,
                                  size: 14,
                                  color: Color(0xFFD4A359),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${h.streak(cutoff)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
  Widget summaryHeader(String title, double width) => Container(
    width: width,
    height: 150,
    alignment: Alignment.bottomCenter,
    padding: EdgeInsets.only(bottom: 20),
    decoration: cellDecoration(color: colors.raised, right: true),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 8,
        color: colors.muted,
        letterSpacing: .7,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  Widget dayHeader(int i, Color color) {
    final d = date(i), today = dayKey(date(i)) == dayKey(widget.now);
    final scheduled = widget.habits.where((h) => h.scheduled(d)).length;
    final done = widget.habits.where((h) => h.scheduled(d) && h.done(d)).length;
    final eligible = !d.isAfter(widget.now) && scheduled > 0;
    final rate = scheduled == 0 ? 0.0 : done / scheduled;
    return Container(
      width: 36,
      height: 125,
      decoration: cellDecoration(
        color: color.withValues(alpha: today ? 0.16 : 0.07),
        right: (i + 1) % 7 == 0 || i == length - 1,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            eligible ? '${(rate * 100).round()}%' : '—',
            style: TextStyle(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 10,
                height: eligible ? math.max(2, rate * 30) : 2,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: eligible ? 0.7 : 0.15),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1],
            style: TextStyle(fontSize: 10, color: colors.muted),
          ),
          SizedBox(height: 5),
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: today ? colors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 10,
                color: today
                    ? Theme.of(context).colorScheme.onPrimary
                    : colors.text,
                fontWeight: today ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: 7),
        ],
      ),
    );
  }

  Widget checkCell(Habit h, int i) {
    final d = date(i),
        color = _weeks[i ~/ 7],
        enabled = canCheckIn(h, date(i), widget.now),
        done = h.done(date(i));
    return Container(
      width: 36,
      height: 62,
      alignment: Alignment.center,
      decoration: cellDecoration(
        color: color.withValues(alpha: .035),
        right: (i + 1) % 7 == 0 || i == length - 1,
      ),
      child: Semantics(
        label: '${h.name}, ${dayKey(d)}, ${done ? 'completed' : 'incomplete'}',
        button: enabled,
        child: Tooltip(
          message:
              '${h.name} · ${dayKey(d)}${enabled
                  ? ''
                  : d.isBefore(widget.now)
                  ? ' · Past day · locked'
                  : ' · Not scheduled / upcoming'}',
          child: SizedBox(
            width: 26,
            height: 28,
            child: Material(
              color: done
                  ? color.withValues(alpha: enabled ? .75 : .48)
                  : enabled
                  ? color.withValues(alpha: .075)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              child: InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: enabled && !widget.busy
                    ? () => widget.onToggle(h, d)
                    : null,
                child: Center(
                  child: done
                      ? Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : !h.scheduled(d) || d.isAfter(widget.now)
                      ? Text(
                          '—',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.muted.withValues(alpha: .4),
                          ),
                        )
                      : Icon(
                          Icons.check_box_outline_blank_rounded,
                          size: 14,
                          color: color.withValues(alpha: enabled ? .5 : .2),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
