import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/app_usage_service.dart';
import 'package:breakmate/features/analytics/focus_session_service.dart';

/// One day's Focus Score (0.0-1.0) for the trend chart.
class FocusTrendPoint {
  final DateTime date;
  final double focusScore;

  const FocusTrendPoint({required this.date, required this.focusScore});
}

/// Turns [days] of daily totals from [usageService]/[focusSessionService]
/// into a trend series — the same per-day Focus Score the Statistics
/// screen already shows for "today" (`focus seconds ÷ total tracked
/// seconds`), just computed once per day instead of once for the selected
/// period. Pure aggregation over data both services already hold; no new
/// tracking.
List<FocusTrendPoint> computeFocusTrend({
  required FocusSessionService focusSessionService,
  required AppUsageService usageService,
  int days = 7,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
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
