import 'dart:async';
import 'package:flutter/widgets.dart';
import 'model.dart';

bool canCheckIn(Habit habit, DateTime day, DateTime systemNow) =>
    dayOnly(day) == dayOnly(systemNow) && habit.scheduled(day);

/// Local device time, refreshed at midnight, on resume, and after clock changes.
class LocalDayClock extends ChangeNotifier with WidgetsBindingObserver {
  final DateTime Function() readTime;
  late DateTime today;
  Timer? _midnight, _poll;
  LocalDayClock({DateTime Function()? readTime})
    : readTime = readTime ?? DateTime.now {
    today = dayOnly(this.readTime());
  }
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  void refresh() {
    final actual = dayOnly(readTime());
    if (actual != today) {
      today = actual;
      _scheduleMidnight();
      notifyListeners();
    }
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = readTime();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(
      next.difference(now) + const Duration(milliseconds: 30),
      refresh,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
      _scheduleMidnight();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
