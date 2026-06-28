import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/boat.dart';

class SpeedSparkline extends StatelessWidget {
  final List<SpeedSample> samples;
  final double height;
  final Color? lineColor;
  final Color? fillColor;

  const SpeedSparkline({
    super.key,
    required this.samples,
    this.height = 32,
    this.lineColor,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'collecting…',
            style: TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final color = lineColor ?? theme.colorScheme.primary;

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(
          samples: samples,
          lineColor: color,
          fillColor: fillColor ?? color.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<SpeedSample> samples;
  final Color lineColor;
  final Color fillColor;

  _SparklinePainter({
    required this.samples,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    final speeds = samples.reversed.map((s) => s.speed).toList();
    final minSpeed = speeds.reduce(math.min);
    final maxSpeed = speeds.reduce(math.max);
    final range = maxSpeed - minSpeed;
    final padding = range * 0.1;
    final effectiveMin = minSpeed - padding;
    final effectiveMax = maxSpeed + padding;
    final effectiveRange = effectiveMax - effectiveMin;

    if (effectiveRange <= 0) {
      final y = size.height / 2;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = lineColor
          ..strokeWidth = 1.5,
      );
      return;
    }

    final points = <Offset>[];
    for (var i = 0; i < speeds.length; i++) {
      final x = (i / (speeds.length - 1)) * size.width;
      final y = size.height - ((speeds[i] - effectiveMin) / effectiveRange) * size.height;
      points.add(Offset(x, y));
    }

    // Fill
    final fillPath = Path()..moveTo(0, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Current value dot
    canvas.drawCircle(
      points.last,
      3,
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => true;
}
