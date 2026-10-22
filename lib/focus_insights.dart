import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'appearance.dart';
import 'desktop_bridge.dart';
import 'model.dart';

class FocusInsights extends StatefulWidget {
  final DateTime month;
  const FocusInsights({super.key, required this.month});
  @override
  State<FocusInsights> createState() => _FocusInsightsState();
}

class _FocusInsightsState extends State<FocusInsights> {
  Timer? poll;
  List<Map<String, dynamic>> sessions = [];
  String? error;
  bool fetching = false;
  @override
  void initState() {
    super.initState();
    refresh();
    poll = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  Future<void> refresh() async {
    if (!isWindowsDesktop || fetching) return;
    fetching = true;
    try {
      final data = jsonDecode(await desktopRequest('focusStats')) as List;
      if (mounted) {
        setState(() {
          sessions = data.map((s) => Map<String, dynamic>.from(s)).toList();
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not read focus time. Try again.');
      }
    } finally {
      fetching = false;
    }
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppPalette(context), grouped = <String, Map<String, dynamic>>{};
    for (final s in sessions) {
      final date = DateTime.parse(s['started'] as String).toLocal();
      if (date.year != widget.month.year || date.month != widget.month.month) {
        continue;
      }
      final key = s['habitId'] as String;
      grouped.putIfAbsent(key, () => {...s, 'seconds': 0.0});
      grouped[key]!['seconds'] =
          (grouped[key]!['seconds'] as num) + (s['seconds'] as num);
    }
    final rows = grouped.values.where((s) => (s['seconds'] as num) > 0).toList()
      ..sort((a, b) => (b['seconds'] as num).compareTo(a['seconds'] as num));
    final total = rows.fold<double>(
      0,
      (sum, r) => sum + (r['seconds'] as num).toDouble(),
    );
    String duration(num seconds) {
      final minutes = (seconds / 60).floor();
      return minutes >= 60
          ? '${minutes ~/ 60}h ${minutes % 60}m'
          : minutes > 0
          ? '${minutes}m'
          : '${seconds.floor()}s';
    }

    final chart = SizedBox(
      width: 210,
      height: 210,
      child: CustomPaint(
        painter: FocusRing(rows, c.border),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                duration(total),
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'focus invested',
                style: TextStyle(color: c.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time invested in habits',
          style: TextStyle(
            color: c.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Selected month · work time only · breaks excluded',
          style: TextStyle(color: c.muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        if (error != null) Text(error!),
        if (rows.isEmpty)
          Text(
            'Start a Pomodoro from Widgets to see your focus grow.',
            style: TextStyle(color: c.muted),
          ),
        ...rows.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: habitColors[r['color'] as int],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${duration(r['seconds'] as num)} · ${((r['seconds'] as num) / total * 100).round()}%',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, size) => size.maxWidth > 650
            ? Row(
                children: [
                  chart,
                  const SizedBox(width: 32),
                  Expanded(child: legend),
                ],
              )
            : Column(children: [chart, const SizedBox(height: 24), legend]),
      ),
    );
  }
}

class FocusRing extends CustomPainter {
  final List<Map<String, dynamic>> rows;
  final Color empty;
  FocusRing(this.rows, this.empty);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 16,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = empty);
    final total = rows.fold<double>(0, (s, r) => s + (r['seconds'] as num));
    if (total == 0) return;
    var angle = -math.pi / 2;
    for (final r in rows) {
      final sweep = (r['seconds'] as num) / total * math.pi * 2;
      canvas.drawArc(
        rect,
        angle,
        sweep > 0.04 ? sweep - 0.025 : sweep,
        false,
        paint..color = habitColors[r['color'] as int],
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant FocusRing oldDelegate) => true;
}
