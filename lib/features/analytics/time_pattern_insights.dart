/// Time-of-day findings — the richest unused signal in BreakMate's history:
/// *when* things happen, not just *how much*. Both functions below are pure
/// aggregation over data already recorded ([BreakHistoryService],
/// [FocusSessionService]) — no new tracking, same as the rest of the
/// insight layer. See the workflow-analysis plan doc §7.2/Phase 4.
library;

import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';

/// Minimum sample size before a per-hour rate is trusted enough to surface
/// — below this, a single unlucky day could look like a pattern.
const int minHourlySampleCount = 3;

/// The hour of day (0-23) with the worst break-skip rate, if there's enough
/// data at that hour to say something real. `null` when every hour is under
/// [minHourlySampleCount] samples.
///
/// Ties broken by earliest hour, for a stable, testable result.
int? worstBreakHour(List<BreakEvent> events) {
  final totalsByHour = <int, int>{};
  final skippedByHour = <int, int>{};

  for (final event in events) {
    final hour = event.time.hour;
    totalsByHour[hour] = (totalsByHour[hour] ?? 0) + 1;
    if (!event.completed) {
      skippedByHour[hour] = (skippedByHour[hour] ?? 0) + 1;
    }
  }

  int? worstHour;
  double worstRate = -1;
  for (final hour in totalsByHour.keys.toList()..sort()) {
    final total = totalsByHour[hour]!;
    if (total < minHourlySampleCount) continue;
    final rate = (skippedByHour[hour] ?? 0) / total;
    if (rate > worstRate) {
      worstRate = rate;
      worstHour = hour;
    }
  }
  return worstHour;
}

/// The break-skip rate at [worstBreakHour], for phrasing the finding.
/// Returns 0.0 if [hour] has no events.
double breakSkipRateAtHour(List<BreakEvent> events, int hour) {
  final atHour = events.where((e) => e.time.hour == hour).toList();
  if (atHour.isEmpty) return 0.0;
  final skipped = atHour.where((e) => !e.completed).length;
  return skipped / atHour.length;
}

/// The hour of day (0-23) with the most total deep-work focus time, if
/// there's enough data to say something real. `null` when there aren't at
/// least [minHourlySampleCount] sessions total.
///
/// Ties broken by earliest hour, for a stable, testable result.
int? goldenFocusHour(List<FocusSession> sessions) {
  if (sessions.length < minHourlySampleCount) return null;

  final secondsByHour = <int, int>{};
  for (final session in sessions) {
    final hour = session.start.hour;
    secondsByHour[hour] = (secondsByHour[hour] ?? 0) + session.durationSeconds;
  }

  int? bestHour;
  var bestSeconds = -1;
  for (final hour in secondsByHour.keys.toList()..sort()) {
    final seconds = secondsByHour[hour]!;
    if (seconds > bestSeconds) {
      bestSeconds = seconds;
      bestHour = hour;
    }
  }
  return bestHour;
}

/// Formats an hour-of-day (0-23) as a friendly label, e.g. `2` → `"2pm"`,
/// `0` → `"12am"`, `13` → `"1pm"`.
String formatHourLabel(int hour) {
  final period = hour < 12 ? 'am' : 'pm';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour$period';
}
