import 'package:flutter/material.dart';

String dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);
const habitColors = [
  Color(0xFF7660D3),
  Color(0xFF48A58B),
  Color(0xFFE0A54F),
  Color(0xFF6A9ACC),
  Color(0xFFD27D92),
  Color(0xFF4285C5),
  Color(0xFF00897B),
  Color(0xFF8E5DA8),
  Color(0xFFDB704C),
  Color(0xFF607D8B),
  Color(0xFFAD8056),
  Color(0xFFB25873),
  Color(0xFF6F9348),
  Color(0xFF5365A5),
  Color(0xFFB09633),
  Color(0xFF5B676D),
];
const habitIcons = [
  Icons.auto_stories_outlined,
  Icons.water_drop_outlined,
  Icons.self_improvement,
  Icons.directions_run,
  Icons.bedtime_outlined,
  Icons.edit_outlined,
  Icons.code,
  Icons.favorite_border,
  Icons.calculate_outlined,
  Icons.translate,
  Icons.music_note_outlined,
  Icons.movie_outlined,
  Icons.sports_esports_outlined,
  Icons.restaurant_outlined,
  Icons.candlestick_chart_outlined,
  Icons.nights_stay_outlined,
  Icons.fitness_center,
  Icons.shower_outlined,
  Icons.brush_outlined,
  Icons.piano_outlined,
  Icons.science_outlined,
  Icons.pets_outlined,
  Icons.cleaning_services_outlined,
  Icons.directions_bike,
  Icons.savings_outlined,
  Icons.work_outline,
];
const habitIconNames = [
  'Reading',
  'Water',
  'Mindfulness',
  'Running',
  'Bedtime',
  'Writing',
  'Coding',
  'Wellness',
  'Maths',
  'Languages',
  'Music',
  'Entertainment',
  'Gaming',
  'Cooking',
  'Trading',
  'Sleep',
  'Gym',
  'Hygiene',
  'Art',
  'Piano',
  'Science',
  'Pets',
  'Cleaning',
  'Cycling',
  'Savings',
  'Work',
];
const habitCategories = [
  'Wellness',
  'Learning',
  'Mindfulness',
  'Fitness',
  'Creativity',
  'Personal',
  'Entertainment',
  'Gaming',
  'Hygiene',
  'Cooking',
  'Finance',
  'Languages',
  'Music',
  'Sleep',
  'Work',
  'Relationships',
];
String monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-01';

class Habit {
  final String id;
  final String name;
  final String category;
  final int color;
  final int icon;
  final DateTime created;
  final Set<int> weekdays;
  final Set<String> checks;
  final int dailyTarget;
  final Map<String, int> dailyCounts;
  final Map<String, dynamic>? reminder;
  Set<String>? months;
  Habit({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.icon,
    required this.created,
    Set<int>? weekdays,
    Set<String>? checks,
    this.dailyTarget = 1,
    Map<String, int>? dailyCounts,
    this.reminder,
    this.months,
  }) : weekdays = weekdays ?? {1, 2, 3, 4, 5, 6, 7},
       checks = checks ?? {},
       dailyCounts = dailyCounts ?? {};
  int countOn(DateTime date) =>
      dailyCounts[dayKey(date)] ?? (done(date) ? dailyTarget : 0);
  void setCount(DateTime date, int count) {
    final key = dayKey(date);
    dailyCounts[key] = count.clamp(0, dailyTarget);
    if (count >= dailyTarget) {
      checks.add(key);
    } else {
      checks.remove(key);
    }
  }

  bool inMonth(DateTime date) =>
      months == null || months!.contains(monthKey(date));
  bool scheduled(DateTime date) =>
      inMonth(date) &&
      !dayOnly(date).isBefore(dayOnly(created)) &&
      weekdays.contains(date.weekday);
  bool done(DateTime date) => checks.contains(dayKey(date));
  int opportunities(DateTime start, DateTime end) {
    var n = 0;
    for (
      var d = dayOnly(start);
      !d.isAfter(dayOnly(end));
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (scheduled(d)) n++;
    }
    return n;
  }

  int completions(DateTime start, DateTime end) {
    var n = 0;
    for (
      var d = dayOnly(start);
      !d.isAfter(dayOnly(end));
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (scheduled(d) && done(d)) n++;
    }
    return n;
  }

  int streak(DateTime now) {
    var count = 0;
    var d = dayOnly(now);
    if (scheduled(d) && !done(d)) d = DateTime(d.year, d.month, d.day - 1);
    for (
      ;
      !d.isBefore(dayOnly(created));
      d = DateTime(d.year, d.month, d.day - 1)
    ) {
      if (!scheduled(d)) continue;
      if (!done(d)) break;
      count++;
    }
    return count;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'color': color,
    'icon': icon,
    'created': dayKey(created),
    'weekdays': weekdays.toList(),
    'checks': checks.toList(),
    'months': months?.toList(),
    'dailyTarget': dailyTarget,
    'dailyCounts': dailyCounts,
    'reminder': reminder,
  };
  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
    id: j['id'] as String,
    name: j['name'] as String,
    category: j['category'] as String,
    color: j['color'] as int,
    icon: j['icon'] as int,
    created: DateTime.parse(j['created'] as String),
    weekdays: (j['weekdays'] as List).cast<int>().toSet(),
    checks: (j['checks'] as List).cast<String>().toSet(),
    months: (j['months'] as List?)?.cast<String>().toSet(),
    dailyTarget: (j['dailyTarget'] as int?) ?? 1,
    dailyCounts: j['dailyCounts'] == null
        ? null
        : Map<String, int>.from(j['dailyCounts'] as Map),
    reminder: j['reminder'] == null
        ? null
        : Map<String, dynamic>.from(j['reminder'] as Map),
  );
}
