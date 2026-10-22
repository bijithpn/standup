import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/features/analytics/segments/productivity_summary.dart';

/// Turns raw segments into the summaries the UI reads.
///
/// Every function here is pure, so a month of history can be rolled up on a
/// background isolate. It deliberately holds no reference to ObjectBox — the
/// store rejects access from secondary isolates, so segments are read on the
/// main isolate and only the plain data crosses over.

/// Stretches shorter than this are absorbed into their neighbour on the
/// timeline. At a 10-second poll these are apps that were passed through
/// rather than used, and drawing each one turns the day into confetti.
const int kTimelineMergeThresholdSeconds = 45;

/// Two stretches further apart than this are not joined: the time between them
/// was not recorded (asleep, tracking off), and stretching one across it would
/// draw time that never happened.
const int kTimelineGapToleranceSeconds = 90;

/// Rolls one day's segments into a summary.
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

        // A switch is a move between two *different* applications. Coming back
        // from idle or a break to the same app is a resumption, not a switch,
        // and counting it would make a quiet day look fragmented.
        if (previousAppKey != null && previousAppKey != segment.appKey) {
          contextSwitches++;
          // Attributed to the hour the switch happened, which is the start of
          // the stretch being switched *into*.
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

/// Adds a segment's seconds to the hours it actually covers.
///
/// A stretch that runs from 09:50 to 10:20 belongs to both hours, and putting
/// all of it in whichever hour it started would bend the shape of the day.
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

/// Rolls several already-aggregated days into one range summary.
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

/// Prepares a day's segments for drawing.
///
/// Adjacent stretches in the same state are joined, and anything too short to
/// read is absorbed into whatever came before it, so the timeline shows the
/// shape of the day rather than every individual poll.
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

    // Too brief to see, and there is something to fold it into.
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
