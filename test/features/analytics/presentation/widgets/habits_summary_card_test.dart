import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/habits_summary.dart';
import 'package:breakmate/features/analytics/presentation/widgets/habits_summary_card.dart';

void main() {
  testWidgets('shows both streak counts and the sync sentence', (
    tester,
  ) async {
    const summary = HabitsSummary(breakStreakDays: 5, focusStreakDays: 5);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HabitsSummaryCard(summary: summary)),
      ),
    );

    expect(find.text('5'), findsNWidgets(2));
    expect(find.text('Break streak'), findsOneWidget);
    expect(find.text('Focus streak'), findsOneWidget);
    expect(find.textContaining('in sync at 5 days'), findsOneWidget);
  });
}
