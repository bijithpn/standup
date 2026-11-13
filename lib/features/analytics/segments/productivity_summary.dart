import 'package:breakmate/core/storage/models/activity_segment.dart';

/// Time and session stats for one app.
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

  final int sessionCount;

  final int longestSessionSeconds;

  Duration get duration => Duration(seconds: seconds);

  int get averageSessionSeconds =>
      sessionCount == 0 ? 0 : seconds ~/ sessionCount;
}

/// Aggregated active/idle/break time, per-app and hourly breakdown for one day.
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

  final String date;

  final int activeSeconds;
  final int idleSeconds;
  final int breakSeconds;

  final int contextSwitches;

  final List<AppTotal> apps;

  final Map<String, int> categorySeconds;

  final List<int> hourlyActiveSeconds;

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

  int get trackedSeconds => activeSeconds + idleSeconds + breakSeconds;

  bool get hasActivity => trackedSeconds > 0;

  AppTotal? get mostUsedApp => apps.isEmpty ? null : apps.first;

  double get switchesPerActiveHour {
    if (activeSeconds <= 0) return 0;
    return contextSwitches / (activeSeconds / 3600);
  }

  double get activeShare =>
      trackedSeconds == 0 ? 0 : activeSeconds / trackedSeconds;

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

/// Aggregated summary over several days, plus the daily summaries.
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

  int get activeDayCount => days.where((day) => day.hasActivity).length;

  int get averageActiveSecondsPerDay =>
      activeDayCount == 0 ? 0 : activeSeconds ~/ activeDayCount;

  AppTotal? get mostUsedApp => apps.isEmpty ? null : apps.first;
}

/// One row of the day timeline (merged segment).
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
