import 'dart:math';
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
];

class Habit {
  final String id;
  final String name;
  final String category;
  final int color;
  final int icon;
  final DateTime created;
  final Set<int> weekdays;
  final Set<String> checks;
  Habit({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.icon,
    required this.created,
    Set<int>? weekdays,
    Set<String>? checks,
  }) : weekdays = weekdays ?? {1, 2, 3, 4, 5, 6, 7},
       checks = checks ?? {};
  bool scheduled(DateTime date) =>
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
  );
}

List<Habit> demoHabits(DateTime now) {
  final random = Random(42);
  final names = [
    'Read 20 pages',
    'Drink enough water',
    'Mindful mornings',
    'Move your body',
    'Sleep before 11',
    'Daily journaling',
  ];
  final categories = [
    'Learning',
    'Wellness',
    'Mindfulness',
    'Fitness',
    'Wellness',
    'Mindfulness',
  ];
  return List.generate(names.length, (i) {
    final h = Habit(
      id: 'demo-$i',
      name: names[i],
      category: categories[i],
      color: i % 5,
      icon: i,
      created: DateTime(now.year, now.month, 1),
    );
    for (
      var d = h.created;
      d.isBefore(dayOnly(now));
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (random.nextDouble() < .76) h.checks.add(dayKey(d));
    }
    if (i < 3) h.checks.add(dayKey(now));
    return h;
  });
}
