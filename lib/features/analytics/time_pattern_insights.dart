library;

import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';

const int minHourlySampleCount = 3;

/// Hour of day with the highest skip rate (ignores hours with too few samples); null if none.
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

double breakSkipRateAtHour(List<BreakEvent> events, int hour) {
  final atHour = events.where((e) => e.time.hour == hour).toList();
  if (atHour.isEmpty) return 0.0;
  final skipped = atHour.where((e) => !e.completed).length;
  return skipped / atHour.length;
}

/// Hour of day in which the most focus time starts; null if too few sessions.
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

String formatHourLabel(int hour) {
  final period = hour < 12 ? 'am' : 'pm';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour$period';
}
