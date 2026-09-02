import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/presentation/widgets/break_statistics_section.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';

void main() {
  testWidgets('shows metric rows and the yearly heatmap caption', (
    tester,
  ) async {
    final stats = StatsModel(
      breaksCompleted: 12,
      breaksSkipped: 3,
      currentStreak: 4,
      longestStreak: 9,
      averageBreaksPerDay: 5.2,
      weeklyData: [
        DailyStats(
          date: '2026-09-01',
          breaksCompleted: 5,
          breaksSkipped: 1,
          usageMinutes: 200,
        ),
        DailyStats(
          date: '2026-09-02',
          breaksCompleted: 7,
          breaksSkipped: 2,
          usageMinutes: 220,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BreakStatisticsSection(stats: stats, selectedFilter: 1),
          ),
        ),
      ),
    );

    expect(find.text('Total Breaks'), findsOneWidget);
    expect(find.text('Current Streak'), findsOneWidget);
    expect(find.text('Best Streak'), findsOneWidget);
    expect(find.textContaining('days with breaks this year'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders cleanly with no history at all', (tester) async {
    const stats = StatsModel();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BreakStatisticsSection(stats: stats, selectedFilter: 0),
          ),
        ),
      ),
    );

    expect(find.text('0 days with breaks this year'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
