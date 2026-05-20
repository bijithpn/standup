import 'dart:math';
import 'package:flutter/material.dart';

class BreakActivityGraph extends StatelessWidget {
  final List<int> dataPoints;
  final Color color;

  const BreakActivityGraph({
    super.key,
    required this.dataPoints,
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
          color: color,
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<int> dataPoints;
  final Color color;

  _GraphPainter({
    required this.dataPoints,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final stepX = size.width / (dataPoints.length - 1);
    final maxVal = dataPoints.reduce(max).toDouble().clamp(5.0, double.infinity);
    
    // Normalize data points to height
    List<Offset> points = [];
    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * stepX;
      final y = size.height - (dataPoints[i] / maxVal * size.height * 0.8) - 10;
      points.add(Offset(x, y));
    }

    // Draw curvy line (Bezier)
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p1.dx, p1.dy,
      );
    }

    canvas.drawPath(path, paint);

    // Draw dots
    for (final point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }

    // Draw end icon (Fire/Streak)
    final lastPoint = points.last;
    final iconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(lastPoint, 10, iconPaint);
    
    // Simplified fire icon drawing (Triangle-ish)
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
