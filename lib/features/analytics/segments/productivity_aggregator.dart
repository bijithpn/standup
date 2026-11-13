import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';

// Timeline: same-app segments shorter than this are merged into neighbours; gaps up to the tolerance are bridged.
const int kTimelineMergeThresholdSeconds = 45;

const int kTimelineGapToleranceSeconds = 90;

/// Folds one day's segments into totals, per-app stats, hourly buckets and context-switch counts.
DailyProductivitySummary aggregateDay(
  String date,
  List<ActivitySegment> segments,
) {
  if (segments.isEmpty) return DailyProductivitySummary.empty(date);

  final ordered = List<ActivitySegment>.of(segments)
    ..sort((a, b) => a.startedAtMs.compareTo(b.startedAtMs));

  var activeSeconds = 0;
  var idleSeconds = 0;
  var breakSeconds = 0;
  var contextSwitches = 0;

  final hourly = List<int>.filled(24, 0);
  final hourlySwitches = List<int>.filled(24, 0);
  final categorySeconds = <String, int>{};
  final byApp = <String, _AppAccumulator>{};

  String? previousAppKey;
  DateTime? firstActivityAt;
  DateTime? lastActivityAt;

  for (final segment in ordered) {
    if (!segment.isValid) continue;
    final seconds = segment.seconds;

    switch (segment.activityKind) {
      case ActivityKind.idle:
        idleSeconds += seconds;
      case ActivityKind.onBreak:
        breakSeconds += seconds;
      case ActivityKind.active:
        activeSeconds += seconds;

        firstActivityAt ??= segment.startedAt;
        lastActivityAt = segment.endedAt;

        if (previousAppKey != null && previousAppKey != segment.appKey) {
          contextSwitches++;

          final hour = segment.startedAt.hour;
          if (hour >= 0 && hour < 24) hourlySwitches[hour]++;
        }
        previousAppKey = segment.appKey;

        categorySeconds[segment.categoryName] =
            (categorySeconds[segment.categoryName] ?? 0) + seconds;

        (byApp[segment.appKey] ??= _AppAccumulator(
            appKey: segment.appKey,
            appName: segment.appName,
            categoryName: segment.categoryName,
          ))
          ..seconds += seconds
          ..sessionCount += 1
          ..longestSessionSeconds =
              seconds > byApp[segment.appKey]!.longestSessionSeconds
              ? seconds
              : byApp[segment.appKey]!.longestSessionSeconds;

        _spreadAcrossHours(segment, hourly);
    }
  }

  final apps = byApp.values.map((a) => a.build()).toList()
    ..sort((left, right) => right.seconds.compareTo(left.seconds));

  return DailyProductivitySummary(
    date: date,
    activeSeconds: activeSeconds,
    idleSeconds: idleSeconds,
    breakSeconds: breakSeconds,
    contextSwitches: contextSwitches,
    apps: apps,
    categorySeconds: categorySeconds,
    hourlyActiveSeconds: hourly,
    hourlySwitches: hourlySwitches,
    firstActivityAt: firstActivityAt,
    lastActivityAt: lastActivityAt,
  );
}

// Splits a segment across hour boundaries so each hour bucket gets its share.
void _spreadAcrossHours(ActivitySegment segment, List<int> hourly) {
  var cursor = segment.startedAt;
  final end = segment.endedAt;

  while (cursor.isBefore(end)) {
    final nextHour = DateTime(
      cursor.year,
      cursor.month,
      cursor.day,
      cursor.hour,
    ).add(const Duration(hours: 1));
    final sliceEnd = nextHour.isBefore(end) ? nextHour : end;
    final slice = sliceEnd.difference(cursor).inSeconds;

    if (cursor.hour >= 0 && cursor.hour < 24) {
      hourly[cursor.hour] += slice;
    }

    if (slice <= 0) break;
    cursor = sliceEnd;
  }
}

/// Combines daily summaries into one multi-day summary.
RangeProductivitySummary aggregateRange(List<DailyProductivitySummary> days) {
  if (days.isEmpty) return RangeProductivitySummary.empty();

  final ordered = List<DailyProductivitySummary>.of(days)
    ..sort((a, b) => a.date.compareTo(b.date));

  var activeSeconds = 0;
  var idleSeconds = 0;
  var breakSeconds = 0;
  var contextSwitches = 0;
  final categorySeconds = <String, int>{};
  final byApp = <String, _AppAccumulator>{};

  for (final day in ordered) {
    activeSeconds += day.activeSeconds;
    idleSeconds += day.idleSeconds;
    breakSeconds += day.breakSeconds;
    contextSwitches += day.contextSwitches;

    day.categorySeconds.forEach((category, seconds) {
      categorySeconds[category] = (categorySeconds[category] ?? 0) + seconds;
    });

    for (final app in day.apps) {
      final accumulator = byApp[app.appKey] ??= _AppAccumulator(
        appKey: app.appKey,
        appName: app.appName,
        categoryName: app.categoryName,
      );
      accumulator.seconds += app.seconds;
      accumulator.sessionCount += app.sessionCount;
      if (app.longestSessionSeconds > accumulator.longestSessionSeconds) {
        accumulator.longestSessionSeconds = app.longestSessionSeconds;
      }
    }
  }

  final apps = byApp.values.map((a) => a.build()).toList()
    ..sort((left, right) => right.seconds.compareTo(left.seconds));

  return RangeProductivitySummary(
    days: ordered,
    activeSeconds: activeSeconds,
    idleSeconds: idleSeconds,
    breakSeconds: breakSeconds,
    contextSwitches: contextSwitches,
    apps: apps,
    categorySeconds: categorySeconds,
  );
}

/// Converts raw segments into display-friendly timeline rows, merging tiny fragments.
List<TimelineEntry> buildTimeline(
  List<ActivitySegment> segments, {
  int mergeThresholdSeconds = kTimelineMergeThresholdSeconds,
}) {
  if (segments.isEmpty) return const <TimelineEntry>[];

  final ordered = List<ActivitySegment>.of(segments)
    ..sort((a, b) => a.startedAtMs.compareTo(b.startedAtMs));

  final entries = <_MutableEntry>[];
  for (final segment in ordered) {
    if (!segment.isValid) continue;

    final last = entries.isEmpty ? null : entries.last;
    final adjacent =
        last != null &&
        segment.startedAt.difference(last.endedAt).inSeconds <=
            kTimelineGapToleranceSeconds;
    final continues =
        adjacent &&
        last.kind == segment.activityKind &&
        last.appKey == segment.appKey;

    if (continues) {
      last.endedAt = segment.endedAt;
      continue;
    }

    if (adjacent && segment.seconds < mergeThresholdSeconds) {
      last.endedAt = segment.endedAt;
      continue;
    }

    entries.add(
      _MutableEntry(
        kind: segment.activityKind,
        appKey: segment.appKey,
        appName: segment.appName,
        categoryName: segment.categoryName,
        startedAt: segment.startedAt,
        endedAt: segment.endedAt,
      ),
    );
  }

  return entries
      .map(
        (entry) => TimelineEntry(
          kind: entry.kind,
          appKey: entry.appKey,
          appName: entry.appName,
          categoryName: entry.categoryName,
          startedAt: entry.startedAt,
          endedAt: entry.endedAt,
        ),
      )
      .toList(growable: false);
}

class _AppAccumulator {
  _AppAccumulator({
    required this.appKey,
    required this.appName,
    required this.categoryName,
  });

  final String appKey;
  final String appName;
  final String categoryName;

  int seconds = 0;
  int sessionCount = 0;
  int longestSessionSeconds = 0;

  AppTotal build() => AppTotal(
    appKey: appKey,
    appName: appName,
    categoryName: categoryName,
    seconds: seconds,
    sessionCount: sessionCount,
    longestSessionSeconds: longestSessionSeconds,
  );
}

class _MutableEntry {
  _MutableEntry({
    required this.kind,
    required this.appKey,
    required this.appName,
    required this.categoryName,
    required this.startedAt,
    required this.endedAt,
  });

  final ActivityKind kind;
  final String appKey;
  final String appName;
  final String categoryName;
  final DateTime startedAt;
  DateTime endedAt;
}
