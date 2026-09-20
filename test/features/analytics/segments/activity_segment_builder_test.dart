import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/segments/activity_segment_builder.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  const poll = Duration(seconds: 10);
  final day = DateTime(2026, 9, 20, 9);

  ActivitySegmentBuilder newBuilder() =>
      ActivitySegmentBuilder(pollInterval: poll);

  ActivitySegment? active(
    ActivitySegmentBuilder builder,
    String app,
    DateTime at, {
    AppCategory category = AppCategory.coding,
  }) {
    return builder.onActive(
      appKey: app,
      appName: app,
      category: category,
      now: at,
    );
  }

  group('accumulating', () {
    test('staying in one app does not close anything', () {
      final builder = newBuilder();

      expect(active(builder, 'code', day), isNull);
      expect(active(builder, 'code', day.add(poll)), isNull);
      expect(active(builder, 'code', day.add(poll * 2)), isNull);
    });

    test('switching apps closes the stretch at the moment of the switch', () {
      final builder = newBuilder();
      active(builder, 'code', day);
      active(builder, 'code', day.add(poll));

      final finished = active(builder, 'chrome', day.add(poll * 2));

      expect(finished, isNotNull);
      expect(finished!.appKey, 'code');
      expect(finished.startedAt, day);
      expect(finished.endedAt, day.add(poll * 2));
      expect(finished.seconds, 20);
      expect(finished.activityKind, ActivityKind.active);
    });

    test('closing returns the open stretch', () {
      final builder = newBuilder();
      active(builder, 'code', day);

      final finished = builder.close(day.add(poll * 3));

      expect(finished, isNotNull);
      expect(finished!.seconds, 30);
    });

    test('closing twice does not invent a second stretch', () {
      final builder = newBuilder();
      active(builder, 'code', day);
      builder.close(day.add(poll));

      expect(builder.close(day.add(poll * 2)), isNull);
    });

    test('a stretch that spans no time is discarded', () {
      final builder = newBuilder();
      active(builder, 'code', day);

      // Two different apps observed at the same instant.
      expect(active(builder, 'chrome', day), isNull);
    });
  });

  group('idle and breaks', () {
    test('going idle closes the active stretch and opens an idle one', () {
      final builder = newBuilder();
      active(builder, 'code', day);

      final finished = builder.onIdle(day.add(poll * 2));

      expect(finished!.appKey, 'code');
      expect(builder.openKind, ActivityKind.idle);
    });

    test('returning from idle records the idle stretch', () {
      final builder = newBuilder();
      active(builder, 'code', day);
      builder.onIdle(day.add(poll));

      final finished = active(builder, 'code', day.add(poll * 4));

      expect(finished!.activityKind, ActivityKind.idle);
      expect(finished.seconds, 30);
      expect(finished.appKey, isEmpty, reason: 'idle belongs to no app');
    });

    test('a break interrupts whatever was open, even another break', () {
      final builder = newBuilder();
      active(builder, 'code', day);

      final closedByBreak = builder.onBreakStarted(day.add(poll));
      expect(closedByBreak!.appKey, 'code');
      expect(builder.openKind, ActivityKind.onBreak);

      final closedBreak = builder.onBreakEnded(day.add(poll * 3));
      expect(closedBreak!.activityKind, ActivityKind.onBreak);
      expect(closedBreak.seconds, 20);
    });

    test('a break is recorded even while the user is idle', () {
      final builder = newBuilder();
      builder.onIdle(day);

      final finished = builder.onBreakStarted(day.add(poll));

      expect(finished!.activityKind, ActivityKind.idle);
      expect(builder.openKind, ActivityKind.onBreak);
    });
  });

  group('day rollover', () {
    test('a stretch running past midnight is split at the boundary', () {
      final builder = newBuilder();
      // One poll apart, so the sleep-gap guard stays out of it.
      final beforeMidnight = DateTime(2026, 9, 20, 23, 59, 55);
      final afterMidnight = DateTime(2026, 9, 21, 0, 0, 5);

      active(builder, 'code', beforeMidnight);
      final finished = active(builder, 'code', afterMidnight);

      expect(finished, isNotNull, reason: 'midnight must close the stretch');
      expect(finished!.date, '2026-09-20');
      expect(finished.endedAt, DateTime(2026, 9, 21));
      expect(finished.seconds, 5);
    });

    test('the stretch after midnight belongs to the new day', () {
      final builder = newBuilder();
      active(builder, 'code', DateTime(2026, 9, 20, 23, 59, 55));
      active(builder, 'code', DateTime(2026, 9, 21, 0, 0, 5));

      final next = builder.close(DateTime(2026, 9, 21, 0, 1));

      expect(next!.date, '2026-09-21');
      expect(next.startedAt, DateTime(2026, 9, 21));
    });
  });

  group('sleep and gaps', () {
    test('a long silence is not attributed to the open app', () {
      final builder = newBuilder();
      active(builder, 'code', day);
      active(builder, 'code', day.add(poll));

      // The machine slept for two hours.
      final finished = active(builder, 'code', day.add(const Duration(hours: 2)));

      expect(finished, isNotNull);
      expect(
        finished!.seconds,
        20,
        reason: 'only the observed time counts, not the gap',
      );
      expect(finished.endedAt, day.add(poll * 2));
    });

    test('the stretch after a gap starts when observation resumed', () {
      final builder = newBuilder();
      active(builder, 'code', day);
      final resumedAt = day.add(const Duration(hours: 2));
      active(builder, 'code', resumedAt);

      final next = builder.close(resumedAt.add(poll));

      expect(next!.startedAt, resumedAt);
      expect(next.seconds, 10);
    });

    test('a late poll within tolerance still accumulates', () {
      final builder = newBuilder();
      active(builder, 'code', day);

      // Two poll intervals late — the loop was busy, the machine was not asleep.
      expect(active(builder, 'code', day.add(poll * 2)), isNull);
    });
  });

  group('recorded detail', () {
    test('carries the app name, category and calendar day', () {
      final builder = newBuilder();
      builder.onActive(
        appKey: 'com.microsoft.vscode',
        appName: 'Code',
        category: AppCategory.coding,
        now: day,
      );

      final finished = builder.close(day.add(poll));

      expect(finished!.appKey, 'com.microsoft.vscode');
      expect(finished.appName, 'Code');
      expect(finished.categoryName, AppCategory.coding.name);
      expect(finished.date, '2026-09-20');
    });

    test('a category is stored by name so reordering cannot corrupt it', () {
      final builder = newBuilder();
      active(builder, 'slack', day, category: AppCategory.meeting);
      final finished = builder.close(day.add(poll));

      expect(finished!.categoryName, 'meeting');
    });
  });
}
