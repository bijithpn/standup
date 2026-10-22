import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/segments/productivity_aggregator.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';

const String _date = '2026-09-20';
final DateTime _day = DateTime(2026, 9, 20);

ActivitySegment seg({
  required int fromMinute,
  required int toMinute,
  String app = 'code',
  String category = 'coding',
  ActivityKind kind = ActivityKind.active,
  DateTime? day,
}) {
  final base = day ?? _day;
  return ActivitySegment(
    appKey: kind == ActivityKind.active ? app : '',
    appName: kind == ActivityKind.active ? app : '',
    categoryName: kind == ActivityKind.active ? category : '',
    date:
        '${base.year}-${base.month.toString().padLeft(2, '0')}-${base.day.toString().padLeft(2, '0')}',
    startedAtMs: base.add(Duration(minutes: fromMinute)).millisecondsSinceEpoch,
    endedAtMs: base.add(Duration(minutes: toMinute)).millisecondsSinceEpoch,
    kind: kind.storedValue,
  );
}

void main() {
  group('aggregateDay', () {
    test('an empty day reports nothing rather than zeroes it invented', () {
      final summary = aggregateDay(_date, const <ActivitySegment>[]);

      expect(summary.hasActivity, isFalse);
      expect(summary.apps, isEmpty);
      expect(summary.mostUsedApp, isNull);
      expect(summary.peakHour, isNull);
    });

    test('splits time between active, idle and break', () {
      final summary = aggregateDay(_date, <ActivitySegment>[
        seg(fromMinute: 540, toMinute: 600), // 09:00–10:00 active
        seg(fromMinute: 600, toMinute: 615, kind: ActivityKind.onBreak),
        seg(fromMinute: 615, toMinute: 645, kind: ActivityKind.idle),
      ]);

      expect(summary.activeSeconds, 60 * 60);
      expect(summary.breakSeconds, 15 * 60);
      expect(summary.idleSeconds, 30 * 60);
      expect(summary.trackedSeconds, 105 * 60);
      expect(summary.activeShare, closeTo(60 / 105, 0.001));
    });

    test('counts a switch only when the application actually changes', () {
      final summary = aggregateDay(_date, <ActivitySegment>[
        seg(fromMinute: 540, toMinute: 550, app: 'code'),
        seg(fromMinute: 550, toMinute: 560, app: 'chrome'),
        seg(fromMinute: 560, toMinute: 570, app: 'code'),
      ]);

      expect(summary.contextSwitches, 2);
    });

    test('returning to the same app after a break is not a switch', () {
      final summary = aggregateDay(_date, <ActivitySegment>[
        seg(fromMinute: 540, toMinute: 550, app: 'code'),
        seg(fromMinute: 550, toMinute: 560, kind: ActivityKind.onBreak),
        seg(fromMinute: 560, toMinute: 570, app: 'code'),
      ]);

      expect(
        summary.contextSwitches,
        0,
        reason: 'picking work back up is resumption, not fragmentation',
      );
    });

    test('switches per active hour is comparable across day lengths', () {
      final shortDay = aggregateDay(_date, <ActivitySegment>[
        seg(fromMinute: 540, toMinute: 570, app: 'code'),
        seg(fromMinute: 570, toMinute: 600, app: 'chrome'),
      ]);

      // One switch across one hour of active time.
      expect(shortDay.switchesPerActiveHour, closeTo(1.0, 0.001));
    });

    test('ranks applications by time and counts their sessions', () {
      final summary = aggregateDay(_date, <ActivitySegment>[
        seg(fromMinute: 540, toMinute: 600, app: 'code'), // 60m
        seg(fromMinute: 600, toMinute: 620, app: 'chrome'), // 20m
        seg(fromMinute: 620, toMinute: 650, app: 'code'), // 30m
      ]);

      expect(summary.apps.first.appKey, 'code');
      expect(summary.apps.first.seconds, 90 * 60);
      expect(summary.apps.first.sessionCount, 2);
      expect(summary.apps.first.longestSessionSeconds, 60 * 60);
      expect(summary.apps.first.averageSessionSeconds, 45 * 60);
      expect(summary.mostUsedApp!.appKey, 'code');
    });

    test('totals time by category', () {
      final summary = aggregateDay(_date, <ActivitySegment>[
        seg(fromMinute: 540, toMinute: 600, app: 'code', category: 'coding'),
        seg(fromMinute: 600, toMinute: 630, app: 'slack', category: 'meeting'),
      ]);

      expect(summary.categorySeconds['coding'], 60 * 60);
      expect(summary.categorySeconds['meeting'], 30 * 60);
    });

    test('records when the day started and finished', () {
      final summary = aggregateDay(_date, <ActivitySegment>[
        seg(fromMinute: 540, toMinute: 600),
        seg(fromMinute: 900, toMinute: 960),
      ]);

      expect(summary.firstActivityAt, _day.add(const Duration(minutes: 540)));
      expect(summary.lastActivityAt, _day.add(const Duration(minutes: 960)));
    });
  });

  group('hourly shape', () {
    test('a stretch spanning two hours is split between them', () {
      final summary = aggregateDay(_date, <ActivitySegment>[
        // 09:50 to 10:20 — ten minutes in one hour, twenty in the next.
        seg(fromMinute: 590, toMinute: 620),
      ]);

      expect(summary.hourlyActiveSeconds[9], 10 * 60);
      expect(summary.hourlyActiveSeconds[10], 20 * 60);
    });

    test('the hourly breakdown adds up to the active total', () {
      final summary = aggregateDay(_date, <ActivitySegment>[
        seg(fromMinute: 545, toMinute: 703),
        seg(fromMinute: 800, toMinute: 921),
      ]);

      final hourlyTotal = summary.hourlyActiveSeconds.fold<int>(
        0,
        (sum, s) => sum + s,
      );
      expect(hourlyTotal, summary.activeSeconds);
    });

    test('finds the busiest hour', () {
      final summary = aggregateDay(_date, <ActivitySegment>[
        seg(fromMinute: 540, toMinute: 560), // 09:00, 20m
        seg(fromMinute: 600, toMinute: 655), // 10:00, 55m
      ]);

      expect(summary.peakHour, 10);
    });

    test('idle time does not shape the work day', () {
      final summary = aggregateDay(_date, <ActivitySegment>[
        seg(fromMinute: 540, toMinute: 600, kind: ActivityKind.idle),
      ]);

      expect(summary.hourlyActiveSeconds[9], 0);
      expect(summary.peakHour, isNull);
    });
  });

  group('aggregateRange', () {
    test('sums days and merges their applications', () {
      final monday = aggregateDay('2026-09-21', <ActivitySegment>[
        seg(
          fromMinute: 540,
          toMinute: 600,
          app: 'code',
          day: DateTime(2026, 9, 21),
        ),
      ]);
      final tuesday = aggregateDay('2026-09-22', <ActivitySegment>[
        seg(
          fromMinute: 540,
          toMinute: 630,
          app: 'code',
          day: DateTime(2026, 9, 22),
        ),
        seg(
          fromMinute: 630,
          toMinute: 660,
          app: 'chrome',
          day: DateTime(2026, 9, 22),
        ),
      ]);

      final range = aggregateRange(<DailyProductivitySummary>[monday, tuesday]);

      expect(range.activeSeconds, (60 + 90 + 30) * 60);
      expect(range.apps.first.appKey, 'code');
      expect(range.apps.first.seconds, 150 * 60);
      expect(range.apps.first.sessionCount, 2);
      expect(range.days.first.date, '2026-09-21');
    });

    test('an average ignores days with no activity', () {
      final worked = aggregateDay('2026-09-21', <ActivitySegment>[
        seg(fromMinute: 540, toMinute: 600, day: DateTime(2026, 9, 21)),
      ]);
      final off = aggregateDay('2026-09-22', const <ActivitySegment>[]);

      final range = aggregateRange(<DailyProductivitySummary>[worked, off]);

      expect(range.activeDayCount, 1);
      expect(
        range.averageActiveSecondsPerDay,
        60 * 60,
        reason: 'a day off should not halve the average',
      );
    });
  });

  group('buildTimeline', () {
    test('joins consecutive stretches in the same app', () {
      final timeline = buildTimeline(<ActivitySegment>[
        seg(fromMinute: 540, toMinute: 550, app: 'code'),
        seg(fromMinute: 550, toMinute: 560, app: 'code'),
      ]);

      expect(timeline, hasLength(1));
      expect(timeline.single.seconds, 20 * 60);
    });

    test('absorbs stretches too short to read', () {
      final timeline = buildTimeline(<ActivitySegment>[
        seg(fromMinute: 540, toMinute: 600, app: 'code'),
        // A ten-second glance at Chrome.
        ActivitySegment(
          appKey: 'chrome',
          appName: 'chrome',
          categoryName: 'browsing',
          date: _date,
          startedAtMs: _day
              .add(const Duration(minutes: 600))
              .millisecondsSinceEpoch,
          endedAtMs: _day
              .add(const Duration(minutes: 600, seconds: 10))
              .millisecondsSinceEpoch,
          kind: ActivityKind.active.storedValue,
        ),
        seg(fromMinute: 601, toMinute: 660, app: 'code'),
      ]);

      expect(
        timeline,
        hasLength(1),
        reason: 'a passing glance should not fragment the timeline',
      );
      expect(timeline.single.appKey, 'code');
    });

    test('keeps a real switch', () {
      final timeline = buildTimeline(<ActivitySegment>[
        seg(fromMinute: 540, toMinute: 600, app: 'code'),
        seg(fromMinute: 600, toMinute: 640, app: 'chrome'),
      ]);

      expect(timeline, hasLength(2));
      expect(timeline.first.appKey, 'code');
      expect(timeline.last.appKey, 'chrome');
    });

    test('distinguishes breaks and idle from work', () {
      final timeline = buildTimeline(<ActivitySegment>[
        seg(fromMinute: 540, toMinute: 600, app: 'code'),
        seg(fromMinute: 600, toMinute: 620, kind: ActivityKind.onBreak),
        seg(fromMinute: 620, toMinute: 700, kind: ActivityKind.idle),
      ]);

      expect(timeline.map((e) => e.kind), <ActivityKind>[
        ActivityKind.active,
        ActivityKind.onBreak,
        ActivityKind.idle,
      ]);
    });

    test('an empty day has an empty timeline', () {
      expect(buildTimeline(const <ActivitySegment>[]), isEmpty);
    });
  });
}
