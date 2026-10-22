import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_activity_graph.dart';

void main() {
  testWidgets('renders without throwing given fewer than 2 points', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BreakActivityGraph(dataPoints: [3])),
      ),
    );
    expect(find.byType(BreakActivityGraph), findsOneWidget);
  });

  testWidgets('renders with per-point colors matching dataPoints length', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BreakActivityGraph(
            dataPoints: [1, 4, 2, 6, 8],
            pointColors: [
              Color(0xFFEF4444),
              Color(0xFFF59E0B),
              Color(0xFFF59E0B),
              Color(0xFF4ADE80),
              Color(0xFF4ADE80),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(BreakActivityGraph), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'falls back to the single color when pointColors length mismatches',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BreakActivityGraph(
              dataPoints: [1, 4, 2],
              pointColors: [Color(0xFFEF4444)],
              color: Color(0xFF32D74B),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
