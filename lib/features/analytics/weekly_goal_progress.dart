import '../settings/experience_preferences.dart';
import 'stats_service.dart' show DailyStats;

class WeeklyGoalProgress {
  final int activeDays;
  final int targetDays;
  final bool restingToday;
  const WeeklyGoalProgress({
    required this.activeDays,
    required this.targetDays,
    required this.restingToday,
  });
  double get progress =>
      targetDays == 0 ? 1 : (activeDays / targetDays).clamp(0.0, 1.0);

  factory WeeklyGoalProgress.calculate(
    List<DailyStats> days,
    DateTime now,
    int plannedTarget,
    ExperiencePreferences preferences,
  ) {
    final window = [
      for (var i = 0; i < 7; i++) DateTime(now.year, now.month, now.day - i),
    ];
    final keys = window.map(ExperiencePreferences.dateKey).toSet();
    final active = days
        .where((d) => keys.contains(d.date) && d.breaksCompleted > 0)
        .map((d) => d.date)
        .toSet()
        .length;
    final available = window
        .where((date) => !preferences.isRestDay(date))
        .length;
    return WeeklyGoalProgress(
      activeDays: active,
      targetDays: plannedTarget.clamp(0, available),
      restingToday: preferences.isRestDay(now),
    );
  }
}
