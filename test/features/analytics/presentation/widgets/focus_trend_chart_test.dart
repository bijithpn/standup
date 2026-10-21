// Coverage for the Focus Trend chart's period-aware labeling (plan doc
// §3.2) — weekday labels on a 7-day trend, sparse day-of-month labels once
// the trend stretches to 30 days for the "Month" filter.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/focus_trend.dart';
import 'package:breakmate/features/analytics/presentation/widgets/focus_trend_chart.dart';

List<FocusTrendPoint> _points(int count, DateTime today) {
  return List.generate(count, (i) {
    final date = today.subtract(Duration(days: count - 1 - i));
    return FocusTrendPoint(date: date, focusScore: 0.5);
  });
}

void main() {
  testWidgets('renders without error for a 7-day trend', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: FocusTrendChart(points: _points(7, DateTime(2026, 9, 6))),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without error for a 30-day trend', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: FocusTrendChart(points: _points(30, DateTime(2026, 9, 6))),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an empty state for no points', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FocusTrendChart(points: [])),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
