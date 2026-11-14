import 'package:clock/clock.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';

class FocusTrendPoint {
  final DateTime date;
  final double focusScore;

  const FocusTrendPoint({required this.date, required this.focusScore});
}

/// Daily focus scores for the last [days] days, oldest first, for the trend chart.
List<FocusTrendPoint> computeFocusTrend({
  required FocusSessionService focusSessionService,
  required AppUsageService usageService,
  int days = 7,
  DateTime? now,
}) {
  final today = now ?? clock.now();
  return List.generate(days, (i) {
    final date = today.subtract(Duration(days: days - 1 - i));
    final totalActiveSeconds = usageService
        .categoryTotals(UsagePeriod.today, now: date)
        .values
        .fold<int>(0, (sum, s) => sum + s);
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final score = focusSessionService.focusScore(
      dateKey,
      totalActiveSeconds: totalActiveSeconds,
    );
    return FocusTrendPoint(date: date, focusScore: score);
  });
}
