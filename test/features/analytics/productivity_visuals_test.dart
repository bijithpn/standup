import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/presentation/productivity/activity_timeline_view.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_cards.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';

TimelineEntry active(int fromHour, int fromMin, int toHour, int toMin) =>
    TimelineEntry(
      kind: ActivityKind.active,
      appKey: 'app',
      appName: 'App',
      categoryName: 'coding',
      startedAt: DateTime(2026, 3, 10, fromHour, fromMin),
      endedAt: DateTime(2026, 3, 10, toHour, toMin),
    );

DailyProductivitySummary day(String date, int activeSeconds) =>
    DailyProductivitySummary.empty(date).copyWithActive(activeSeconds);

extension on DailyProductivitySummary {
  DailyProductivitySummary copyWithActive(int seconds) =>
      DailyProductivitySummary(
        date: date,
        activeSeconds: seconds,
        idleSeconds: 0,
        breakSeconds: 0,
        contextSwitches: 0,
        apps: const [],
        categorySeconds: const {},
        hourlyActiveSeconds: hourlyActiveSeconds,
        hourlySwitches: hourlySwitches,
        firstActivityAt: null,
        lastActivityAt: null,
      );
}

void main() {
  group('overview wording', () {
    test('summary sentence names what the time was spent on', () {
      expect(
        ProductivityOverviewCard.summarySentence(
          activeSeconds: 5 * 3600 + 10 * 60,
          breakSeconds: 25 * 60,
          idleSeconds: 40 * 60,
        ),
        'You worked for 5h 10m, took 25m of breaks and were away for 40m.',
      );
    });

    test('summary sentence drops parts that are zero', () {
      expect(
        ProductivityOverviewCard.summarySentence(
          activeSeconds: 3600,
          breakSeconds: 0,
          idleSeconds: 0,
        ),
        'You worked for 1h.',
      );
      expect(
        ProductivityOverviewCard.summarySentence(
          activeSeconds: 0,
          breakSeconds: 0,
          idleSeconds: 0,
        ),
        'No active time recorded yet.',
      );
    });

    test('app switching is described, not just counted', () {
      expect(ProductivityOverviewCard.switchingVerdict(3, 10), 'Steady focus');
      expect(
        ProductivityOverviewCard.switchingVerdict(8, 40),
        'Some app switching',
      );
      expect(
        ProductivityOverviewCard.switchingVerdict(20, 90),
        'A lot of app switching',
      );
      expect(ProductivityOverviewCard.switchingVerdict(null, 0), isNull);
    });
  });

  group('overview card', () {
    Future<void> pump(WidgetTester tester, {int? goal, int active = 7200}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductivityOverviewCard(
                activeSeconds: active,
                idleSeconds: 1800,
                breakSeconds: 900,
                contextSwitches: 24,
                switchesPerHour: 12,
                focusGoalSeconds: goal,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the split and the sentence', (tester) async {
      await pump(tester);
      expect(find.text('Working'), findsOneWidget);
      expect(find.text('Breaks'), findsOneWidget);
      expect(find.text('Away'), findsOneWidget);
      expect(find.text('App switches'), findsOneWidget);
      expect(find.textContaining('You worked for 2h'), findsOneWidget);
    });

    testWidgets('shows progress towards the focus goal', (tester) async {
      await pump(tester, goal: 4 * 3600);
      expect(find.textContaining('50% of 4h goal'), findsOneWidget);
    });

    testWidgets('celebrates reaching the goal', (tester) async {
      await pump(tester, goal: 3600, active: 7200);
      expect(find.text('Goal reached'), findsOneWidget);
    });

    testWidgets('has no overflow on a narrow window', (tester) async {
      tester.view.physicalSize = const Size(380, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pump(tester, goal: 3600);
      expect(tester.takeException(), isNull);
    });
  });

  group('daily bars', () {
    final days = [
      day('2026-03-08', 2 * 3600),
      day('2026-03-09', 6 * 3600),
      day('2026-03-10', 8 * 3600),
    ];

    testWidgets('explain the goal line and colours when a goal is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyActivityBars(days: days, goalSeconds: 6 * 3600),
          ),
        ),
      );
      expect(find.text('Reached goal'), findsOneWidget);
      expect(find.text('Below goal'), findsOneWidget);
      expect(find.text('Dashed line = daily goal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('show no goal legend without a goal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DailyActivityBars(days: days)),
        ),
      );
      expect(find.text('Reached goal'), findsNothing);
    });

    testWidgets('keep the goal line on the chart when goal exceeds data', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyActivityBars(
              days: [day('2026-03-10', 3600)],
              goalSeconds: 10 * 3600,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('10h'), findsWidgets);
    });
  });

  group('timeline', () {
    test('names the busiest hour', () {
      final caption = busiestHourCaption([
        active(9, 0, 9, 20),
        active(11, 0, 12, 0),
        active(15, 0, 15, 30),
      ]);
      expect(caption, 'Most active around 11am (1h)');
    });

    test('splits a stretch that crosses an hour', () {
      final caption = busiestHourCaption([active(10, 30, 11, 45)]);
      // 10:30–11:00 = 30m, 11:00–11:45 = 45m.
      expect(caption, 'Most active around 11am (45m)');
    });

    test('ignores idle and break time', () {
      final idle = TimelineEntry(
        kind: ActivityKind.idle,
        appKey: '',
        appName: '',
        categoryName: '',
        startedAt: DateTime(2026, 3, 10, 9),
        endedAt: DateTime(2026, 3, 10, 12),
      );
      expect(busiestHourCaption([idle]), isNull);
      expect(busiestHourCaption(const []), isNull);
    });

    testWidgets('shows a legend and the busiest hour', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityTimelineView(
              entries: [active(10, 0, 11, 30), active(14, 0, 14, 20)],
            ),
          ),
        ),
      );
      expect(find.text('Working in an app'), findsOneWidget);
      expect(find.text('On a break'), findsOneWidget);
      expect(find.text('Away'), findsOneWidget);
      expect(find.textContaining('Most active around 10am'), findsOneWidget);
    });
  });
}
