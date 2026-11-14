import '../settings/settings_model.dart';
import '../settings/experience_preferences.dart';
import '../feedback/timing_suggestion.dart';
import 'stats_service.dart' show DailyStats;

/// One descriptive observation from an actual seven-day window. No health or
/// productivity causation is inferred from break counts.
class WeeklyActionableInsight {
  final String observation;
  final TimingSuggestion? suggestion;
  const WeeklyActionableInsight(this.observation, [this.suggestion]);

  factory WeeklyActionableInsight.fromDays(
    List<DailyStats> days,
    SettingsModel settings,
    DateTime now,
  ) {
    final keys = {
      for (var i = 0; i < 7; i++)
        ExperiencePreferences.dateKey(
          DateTime(now.year, now.month, now.day - i),
        ),
    };
    final recent = days.where((d) => keys.contains(d.date)).toList();
    final completed = recent.fold<int>(0, (sum, d) => sum + d.breaksCompleted);
    final skipped = recent.fold<int>(0, (sum, d) => sum + d.breaksSkipped);
    final activeDays = recent
        .where((d) => d.breaksCompleted + d.breaksSkipped > 0)
        .map((d) => d.date)
        .toSet()
        .length;
    final total = completed + skipped;
    if (activeDays < 3 || total < 5) {
      return WeeklyActionableInsight(
        'You have $completed completed breaks across $activeDays recorded ${activeDays == 1 ? 'day' : 'days'} this week. A few more days will make patterns clearer.',
      );
    }
    if (skipped / total >= 0.35) {
      return WeeklyActionableInsight(
        'You skipped $skipped of $total offered breaks over the last 7 days. A less frequent rhythm may be worth trying.',
        TimingSuggestion.tooFrequent(settings),
      );
    }
    return WeeklyActionableInsight(
      'You completed $completed of $total offered breaks over the last 7 days. Keep the rhythm if it feels comfortable.',
    );
  }
}
