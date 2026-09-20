import 'package:breakmate/core/storage/models/activity_segment.dart';

/// Rolled-up views of the activity timeline.
///
/// Pure value types with no Flutter or database dependency, so aggregation can
/// run on a background isolate and the UI can hold the result without keeping
/// thousands of raw segments alive.

/// One application's share of a day.
class AppTotal {
  const AppTotal({
    required this.appKey,
    required this.appName,
    required this.categoryName,
    required this.seconds,
    required this.sessionCount,
    required this.longestSessionSeconds,
  });

  final String appKey;
  final String appName;
  final String categoryName;
  final int seconds;

  /// How many separate times this app was returned to.
  final int sessionCount;

  final int longestSessionSeconds;

  Duration get duration => Duration(seconds: seconds);

  int get averageSessionSeconds =>
      sessionCount == 0 ? 0 : seconds ~/ sessionCount;
}

/// A single day of activity.
class DailyProductivitySummary {
  const DailyProductivitySummary({
    required this.date,
    required this.activeSeconds,
    required this.idleSeconds,
    required this.breakSeconds,
    required this.contextSwitches,
    required this.apps,
    required this.categorySeconds,
    required this.hourlyActiveSeconds,
    required this.hourlySwitches,
    this.firstActivityAt,
    this.lastActivityAt,
  });

  /// `YYYY-MM-DD`.
  final String date;

  final int activeSeconds;
  final int idleSeconds;
  final int breakSeconds;

  /// How many times the active application changed.
  final int contextSwitches;

  /// Applications, busiest first.
  final List<AppTotal> apps;

  final Map<String, int> categorySeconds;

  /// Active seconds per hour of the day, index 0–23. The shape of the work
  /// day, and the basis for every "when are you at your best" observation.
  final List<int> hourlyActiveSeconds;

  /// Context switches per hour of the day, index 0–23. Separate from the day
  /// total because "did my focus fall apart after lunch" is a question about
  /// *when* the switching happened, which a single number cannot answer.
  final List<int> hourlySwitches;

  final DateTime? firstActivityAt;
  final DateTime? lastActivityAt;

  static DailyProductivitySummary empty(String date) =>
      DailyProductivitySummary(
        date: date,
        activeSeconds: 0,
        idleSeconds: 0,
        breakSeconds: 0,
        contextSwitches: 0,
        apps: const <AppTotal>[],
        categorySeconds: const <String, int>{},
        hourlyActiveSeconds: List<int>.filled(24, 0),
        hourlySwitches: List<int>.filled(24, 0),
      );

  /// Everything the day accounted for, however it was spent.
  int get trackedSeconds => activeSeconds + idleSeconds + breakSeconds;

  bool get hasActivity => trackedSeconds > 0;

  AppTotal? get mostUsedApp => apps.isEmpty ? null : apps.first;

  /// Switches per hour of *active* time, which is comparable between a long
  /// day and a short one in a way the raw count is not.
  double get switchesPerActiveHour {
    if (activeSeconds <= 0) return 0;
    return contextSwitches / (activeSeconds / 3600);
  }

  /// The share of tracked time actually spent working, 0–1.
  double get activeShare =>
      trackedSeconds == 0 ? 0 : activeSeconds / trackedSeconds;

  /// Switches per active hour within [fromHour] (inclusive) and [toHour]
  /// (exclusive), or null when that stretch holds too little activity to
  /// compare fairly.
  double? switchRateBetween(int fromHour, int toHour, {int minSeconds = 900}) {
    var seconds = 0;
    var switches = 0;
    for (var hour = fromHour; hour < toHour && hour < 24; hour++) {
      if (hour < 0) continue;
      seconds += hourlyActiveSeconds[hour];
      switches += hourlySwitches[hour];
    }
    if (seconds < minSeconds) return null;
    return switches / (seconds / 3600);
  }

  /// The busiest hour of the day, or null if nothing was recorded.
  int? get peakHour {
    var best = -1;
    var bestSeconds = 0;
    for (var hour = 0; hour < hourlyActiveSeconds.length; hour++) {
      if (hourlyActiveSeconds[hour] > bestSeconds) {
        bestSeconds = hourlyActiveSeconds[hour];
        best = hour;
      }
    }
    return best < 0 ? null : best;
  }
}

/// Several days rolled together, for the week and month views.
class RangeProductivitySummary {
  const RangeProductivitySummary({
    required this.days,
    required this.activeSeconds,
    required this.idleSeconds,
    required this.breakSeconds,
    required this.contextSwitches,
    required this.apps,
    required this.categorySeconds,
  });

  /// The days in the range, oldest first. Days with no activity are included
  /// so charts keep an even spacing.
  final List<DailyProductivitySummary> days;

  final int activeSeconds;
  final int idleSeconds;
  final int breakSeconds;
  final int contextSwitches;
  final List<AppTotal> apps;
  final Map<String, int> categorySeconds;

  static RangeProductivitySummary empty() => const RangeProductivitySummary(
        days: <DailyProductivitySummary>[],
        activeSeconds: 0,
        idleSeconds: 0,
        breakSeconds: 0,
        contextSwitches: 0,
        apps: <AppTotal>[],
        categorySeconds: <String, int>{},
      );

  bool get hasActivity => days.any((day) => day.hasActivity);

  /// Days that recorded any activity at all — the denominator for "average
  /// per day", which should not be diluted by weekends the machine was off.
  int get activeDayCount => days.where((day) => day.hasActivity).length;

  int get averageActiveSecondsPerDay =>
      activeDayCount == 0 ? 0 : activeSeconds ~/ activeDayCount;

  AppTotal? get mostUsedApp => apps.isEmpty ? null : apps.first;
}

/// A contiguous stretch ready to draw on a timeline.
///
/// Short flickers are merged away before this point, so the timeline shows the
/// shape of the day rather than every poll.
class TimelineEntry {
  const TimelineEntry({
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
  final DateTime endedAt;

  Duration get duration => endedAt.difference(startedAt);

  int get seconds => duration.inSeconds;
}
