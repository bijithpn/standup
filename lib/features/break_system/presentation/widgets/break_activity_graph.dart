import 'dart:math';
import 'package:flutter/material.dart';

class BreakActivityGraph extends StatelessWidget {
  final List<int> dataPoints;

  /// One color per entry in [dataPoints]. When supplied (and matching
  /// [dataPoints]'s length), each line segment is drawn as a gradient
  /// between its two endpoint colors and the trailing flame dot uses the
  /// last color — used to show a red/amber/green completion trend. Falls
  /// back to a single [color] otherwise.
  final List<Color>? pointColors;
  final Color color;

  const BreakActivityGraph({
    super.key,
    required this.dataPoints,
    this.pointColors,
    this.color = const Color(0xFF32D74B),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: CustomPaint(
        painter: _GraphPainter(
          dataPoints: dataPoints,
          pointColors: pointColors,
          color: color,
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<int> dataPoints;
  final List<Color>? pointColors;
  final Color color;

  _GraphPainter({
    required this.dataPoints,
    required this.pointColors,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    final colors =
        pointColors != null && pointColors!.length == dataPoints.length
        ? pointColors!
        : List<Color>.filled(dataPoints.length, color);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final stepX = size.width / (dataPoints.length - 1);
    final maxVal = dataPoints
        .reduce(max)
        .toDouble()
        .clamp(5.0, double.infinity);

    final points = <Offset>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * stepX;
      final y = size.height - (dataPoints[i] / maxVal * size.height * 0.8) - 10;
      points.add(Offset(x, y));
    }

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      final segment = Path()
        ..moveTo(p0.dx, p0.dy)
        ..cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          p1.dx,
          p1.dy,
        );

      final segmentPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [colors[i], colors[i + 1]],
        ).createShader(Rect.fromPoints(p0, p1));
      canvas.drawPath(segment, segmentPaint);
    }

    for (final point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }

    final lastPoint = points.last;
    final iconPaint = Paint()
      ..color = colors.last
      ..style = PaintingStyle.fill;

    canvas.drawCircle(lastPoint, 10, iconPaint);

    final iconPath = Path()
      ..moveTo(lastPoint.dx, lastPoint.dy - 5)
      ..lineTo(lastPoint.dx - 4, lastPoint.dy + 3)
      ..lineTo(lastPoint.dx + 4, lastPoint.dy + 3)
      ..close();
    canvas.drawPath(iconPath, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
