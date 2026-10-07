import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Donut chart drawn by hand, so the app needs no chart package.
class DonutPainter extends CustomPainter {
  DonutPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
  });

  final List<double> values;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    const gap = 0.025;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      final visible = (values.length > 1 && sweep > gap * 2) ? sweep - gap : sweep;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors[i % colors.length];
      canvas.drawArc(rect, start + (sweep - visible) / 2, visible, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) => true;
}

/// A ring that fills up as a savings goal progresses.
class RingPainter extends CustomPainter {
  RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

/// One bar per day of the month. Taller means more spent that day.
class DailyBars extends StatelessWidget {
  const DailyBars({
    super.key,
    required this.days,
    required this.barColor,
    required this.emptyColor,
    this.height = 90,
  });

  final List<int> days;
  final Color barColor;
  final Color emptyColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    var maxValue = 0;
    for (final d in days) {
      if (d > maxValue) maxValue = d;
    }
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: (d <= 0 || maxValue <= 0)
                        ? 0.04
                        : (d / maxValue).clamp(0.08, 1.0).toDouble(),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: d > 0 ? barColor : emptyColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
