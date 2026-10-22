import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/presentation/productivity/activity_timeline_view.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_cards.dart';
import 'package:breakmate/features/analytics/segments/productivity_aggregator.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight.dart';
import 'package:breakmate/features/analytics/segments/productivity_insight_engine.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';

final _day = DateTime(2026, 3, 10);
const _date = '2026-03-10';

ActivitySegment seg(
  int fromMinute,
  int toMinute, {
  String app = 'code',
  ActivityKind kind = ActivityKind.active,
}) => ActivitySegment(
  appKey: kind == ActivityKind.active ? app : '',
  appName: kind == ActivityKind.active ? app : '',
  categoryName: kind == ActivityKind.active ? 'coding' : '',
  date: _date,
  startedAtMs: _day.add(Duration(minutes: fromMinute)).millisecondsSinceEpoch,
  endedAtMs: _day.add(Duration(minutes: toMinute)).millisecondsSinceEpoch,
  kind: kind.storedValue,
);

TimelineEntry entry(int fromMinute, int toMinute) => TimelineEntry(
  kind: ActivityKind.active,
  appKey: 'code',
  appName: 'code',
  categoryName: 'coding',
  startedAt: _day.add(Duration(minutes: fromMinute)),
  endedAt: _day.add(Duration(minutes: toMinute)),
);

DailyProductivitySummary summary({
  String date = _date,
  int active = 0,
  int breaks = 0,
  int idle = 0,
}) => DailyProductivitySummary(
  date: date,
  activeSeconds: active,
  idleSeconds: idle,
  breakSeconds: breaks,
  contextSwitches: 0,
  apps: const [],
  categorySeconds: const {},
  hourlyActiveSeconds: List<int>.filled(24, 0),
  hourlySwitches: List<int>.filled(24, 0),
);

RangeProductivitySummary range(List<DailyProductivitySummary> days) =>
    RangeProductivitySummary(
      days: days,
      activeSeconds: days.fold(0, (s, d) => s + d.activeSeconds),
      idleSeconds: 0,
      breakSeconds: 0,
      contextSwitches: 0,
      apps: const [],
      categorySeconds: const {},
    );

ProductivityInsight? byId(List<ProductivityInsight> list, String id) {
  for (final i in list) {
    if (i.id == id) return i;
  }
  return null;
}

void main() {
  group('timeline does not invent time', () {
    test('a gap between two stretches in the same app is kept as a gap', () {
      // One minute at 11:19, another at 11:58 — nothing recorded between.
      final timeline = buildTimeline([seg(679, 680), seg(718, 719)]);
      expect(timeline.length, 2);
      expect(timeline.first.seconds, 60);
      expect(timeline.last.seconds, 60);
    });

    test('back-to-back stretches in the same app still join', () {
      final timeline = buildTimeline([seg(600, 610), seg(610, 620)]);
      expect(timeline.length, 1);
      expect(timeline.single.seconds, 20 * 60);
    });

    test('a small recording gap is tolerated', () {
      final a = seg(600, 610);
      final b = ActivitySegment(
        appKey: 'code',
        appName: 'code',
        categoryName: 'coding',
        date: _date,
        startedAtMs: _day
            .add(const Duration(minutes: 610, seconds: 30))
            .millisecondsSinceEpoch,
        endedAtMs: _day
            .add(const Duration(minutes: 620))
            .millisecondsSinceEpoch,
        kind: ActivityKind.active.storedValue,
      );
      expect(buildTimeline([a, b]).length, 1);
    });
  });

  group('timeline view', () {
    Future<void> pump(WidgetTester tester, List<TimelineEntry> entries) {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityTimelineView(
                entries: entries,
                now: _day.add(const Duration(hours: 12)),
              ),
            ),
          ),
        ),
      );
    }

    test('longest focus and per-hour totals', () {
      final entries = [entry(600, 640), entry(700, 730)];
      expect(longestFocusSeconds(entries), 40 * 60);
      final byHour = activeSecondsByHour(entries);
      expect(byHour[10], 40 * 60);
      // 11:40–12:10 splits across two hours.
      expect(byHour[11], 20 * 60);
      expect(byHour[12], 10 * 60);
    });

    testWidgets('shows the facts, hour bars and the legend', (tester) async {
      await pump(tester, [entry(600, 640), entry(700, 760)]);
      expect(find.text('Started '), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('Latest '), findsOneWidget);
      expect(find.text('Longest focus '), findsOneWidget);
      expect(find.text('Active time per hour'), findsOneWidget);
      expect(find.text('Empty = not recorded'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('has no overflow on a narrow window', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityTimelineView(entries: [entry(600, 700)]),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('personal insights', () {
    final history = range([
      summary(date: '2026-03-08', active: 4 * 3600),
      summary(date: '2026-03-09', active: 4 * 3600),
      summary(date: _date, active: 6 * 3600),
    ]);

    test('suggests a break when a long time passes without one', () {
      final result = generateInsights(
        range: history,
        today: summary(active: 2 * 3600),
      );
      final noBreak = byId(result, 'today-no-break')!;
      expect(noBreak.suggestion, isNotNull);
      expect(
        result.first.id,
        'today-no-break',
        reason: 'most actionable first',
      );
    });

    test('does not nag when a break was taken', () {
      final result = generateInsights(
        range: history,
        today: summary(active: 2 * 3600, breaks: 600),
      );
      expect(byId(result, 'today-no-break'), isNull);
    });

    test('flags a very long unbroken stretch', () {
      final result = generateInsights(
        range: history,
        today: summary(active: 2 * 3600, breaks: 600),
        todayTimeline: [entry(540, 540 + 95)],
      );
      expect(byId(result, 'today-long-stretch'), isNotNull);
    });

    test('notices work done only in short bursts', () {
      final result = generateInsights(
        range: history,
        today: summary(active: 2 * 3600, breaks: 600),
        todayTimeline: [entry(540, 550), entry(600, 612), entry(700, 710)],
      );
      final burst = byId(result, 'today-short-bursts')!;
      expect(burst.suggestion, contains('25-minute'));
    });

    test('reports progress to the goal, then celebrates reaching it', () {
      final progress = generateInsights(
        range: history,
        today: summary(active: 2 * 3600, breaks: 600),
        focusGoalSeconds: 4 * 3600,
      );
      final p = byId(progress, 'today-goal-progress')!;
      expect(p.title, '50% of today\'s goal');
      expect(p.description, contains('to go'));

      final done = generateInsights(
        range: history,
        today: summary(active: 5 * 3600, breaks: 600),
        focusGoalSeconds: 4 * 3600,
      );
      expect(byId(done, 'today-goal-reached'), isNotNull);
      expect(byId(done, 'today-goal-progress'), isNull);
    });

    test('compares today with your usual day only when it is meaningful', () {
      final busy = generateInsights(
        range: history,
        today: summary(active: 6 * 3600, breaks: 600),
      );
      final vs = byId(busy, 'today-vs-usual')!;
      expect(vs.title, 'A busier day than usual');
      expect(vs.description, contains('50% more'));

      final similar = generateInsights(
        range: history,
        today: summary(active: 4 * 3600 + 600, breaks: 600),
      );
      expect(byId(similar, 'today-vs-usual'), isNull);
    });

    test('says nothing about the goal or the past without data', () {
      final result = generateInsights(
        range: range([summary(active: 3 * 3600, breaks: 600)]),
        today: summary(active: 3 * 3600, breaks: 600),
      );
      expect(byId(result, 'today-vs-usual'), isNull);
      expect(byId(result, 'today-goal-progress'), isNull);
    });
  });

  group('insight card', () {
    Future<void> pump(WidgetTester tester, ProductivityInsight insight) {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InsightCard(insight: insight)),
        ),
      );
    }

    testWidgets('shows what to do when there is a suggestion', (tester) async {
      await pump(
        tester,
        const ProductivityInsight(
          id: 'x',
          type: InsightType.breakPattern,
          title: 'No break yet today',
          description: 'You have worked 2h without a break.',
          confidence: InsightConfidence.high,
          evidenceDayCount: 1,
          suggestion: 'Stand up for five minutes now.',
        ),
      );
      expect(find.text('BREAKS'), findsOneWidget);
      expect(find.text('No break yet today'), findsOneWidget);
      expect(find.text('Stand up for five minutes now.'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
    });

    testWidgets('has no suggestion box when there is none', (tester) async {
      await pump(
        tester,
        const ProductivityInsight(
          id: 'y',
          type: InsightType.applicationPattern,
          title: 'Code',
          description: '2h today.',
          confidence: InsightConfidence.high,
          evidenceDayCount: 1,
        ),
      );
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsNothing);
    });
  });
}
