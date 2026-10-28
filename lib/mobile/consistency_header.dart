import 'package:flutter/material.dart';
import '../model.dart';

/// Calendar-day completion, using the same definition as the desktop curve.
/// Unscheduled days remain gaps rather than being presented as failures.
List<double?> headerConsistency(List<Habit> habits, DateTime today) =>
    List.generate(21, (i) {
      final day = DateTime(today.year, today.month, today.day - 20 + i);
      final scheduled = habits.where((h) => h.scheduled(day)).toList();
      return scheduled.isEmpty
          ? null
          : scheduled.where((h) => h.done(day)).length / scheduled.length;
    });

class ConsistencyHeader extends StatelessWidget {
  final List<Habit> habits;
  final DateTime today;
  final Color accent, background;
  final Widget child;
  const ConsistencyHeader({
    super.key,
    required this.habits,
    required this.today,
    required this.accent,
    required this.background,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: CustomPaint(
              painter: ConsistencyBackdrop(
                headerConsistency(habits, today),
                accent,
              ),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  background,
                  background.withValues(alpha: .92),
                  background.withValues(alpha: .18),
                  background.withValues(alpha: .02),
                ],
                stops: const [0, .34, .72, 1],
              ),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

class ConsistencyBackdrop extends CustomPainter {
  final List<double?> values;
  final Color accent;
  ConsistencyBackdrop(this.values, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || values.every((v) => v == null)) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final left = size.width * .25, width = size.width * .72;
    final top = size.height * .12, height = size.height * .75;
    for (var i = 0; i < 4; i++) {
      final y = top + height * i / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width, y),
        Paint()
          ..color = accent.withValues(alpha: .045)
          ..strokeWidth = 1,
      );
    }
    final stroke = Paint()
      ..color = accent.withValues(alpha: .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    var points = <Offset>[];
    void drawSegment() {
      if (points.isEmpty) return;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final previous = points[i - 1], next = points[i];
        final middle = (previous.dx + next.dx) / 2;
        path.cubicTo(middle, previous.dy, middle, next.dy, next.dx, next.dy);
      }
      if (points.length > 1) {
        final fill = Path.from(path)
          ..lineTo(points.last.dx, size.height)
          ..lineTo(points.first.dx, size.height)
          ..close();
        canvas.drawPath(
          fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: .13),
                accent.withValues(alpha: 0),
              ],
            ).createShader(Offset.zero & size),
        );
        canvas.drawPath(path, stroke);
      }
      final last = points.last;
      canvas.drawCircle(
        last,
        5,
        Paint()..color = accent.withValues(alpha: .09),
      );
      canvas.drawCircle(
        last,
        2.5,
        Paint()..color = accent.withValues(alpha: .3),
      );
      points = [];
    }

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        drawSegment();
        continue;
      }
      points.add(
        Offset(
          left + width * i / (values.length - 1),
          top + height * (1 - value.clamp(0, 1)),
        ),
      );
    }
    drawSegment();
    canvas.restore();
  }

  @override
  bool shouldRepaint(ConsistencyBackdrop oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.values.length != values.length ||
      List.generate(
        values.length,
        (i) => i,
      ).any((i) => oldDelegate.values[i] != values[i]);
}
