import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/analytics/weekly_actionable_insight.dart';
import 'package:breakmate/features/analytics/weekly_goal_progress.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/experience_preferences.dart';

void main() {
  final now = DateTime(2026, 11, 16);
  DailyStats day(String key, int done, [int skipped = 0]) => DailyStats(
    date: key,
    breaksCompleted: done,
    breaksSkipped: skipped,
    usageMinutes: 0,
  );
  test(
    'weekly insight excludes old and future data and does not advise on a sparse week',
    () {
      final insight = WeeklyActionableInsight.fromDays(
        [
          day('2026-11-16', 2),
          day('2026-11-09', 50, 50),
          day('2026-11-17', 50, 50),
        ],
        const SettingsModel(),
        now,
      );
      expect(
        insight.observation,
        contains('2 completed breaks across 1 recorded day'),
      );
      expect(insight.suggestion, isNull);
    },
  );
  test('a recorded skip pattern produces one optional proposal', () {
    final insight = WeeklyActionableInsight.fromDays(
      [
        day('2026-11-16', 1, 3),
        day('2026-11-15', 2, 2),
        day('2026-11-14', 1, 1),
      ],
      const SettingsModel(),
      now,
    );
    expect(insight.observation, contains('6 of 10'));
    expect(insight.suggestion!.intervalMinutes, 25);
  });
  test('a comfortable weekly pattern does not propose needless changes', () {
    final insight = WeeklyActionableInsight.fromDays(
      [day('2026-11-16', 4), day('2026-11-15', 4), day('2026-11-14', 4)],
      const SettingsModel(),
      now,
    );
    expect(insight.suggestion, isNull);
    expect(insight.observation, contains('12 of 12'));
  });
  test(
    'rest days reduce an unreachable weekly target and do not count as activity',
    () {
      const preferences = ExperiencePreferences(
        restDays: [6, 7],
        restDates: ['2026-11-16'],
      );
      final progress = WeeklyGoalProgress.calculate(
        [day('2026-11-13', 1), day('2026-11-13', 1), day('2026-11-09', 20)],
        now,
        5,
        preferences,
      );
      expect(progress.targetDays, 4);
      expect(progress.activeDays, 1);
      expect(progress.restingToday, isTrue);
      expect(progress.progress, 0.25);
    },
  );
  test('a full rest week has no unfulfilled target or invalid progress', () {
    final progress = WeeklyGoalProgress.calculate(
      [],
      now,
      5,
      const ExperiencePreferences(restDays: [1, 2, 3, 4, 5, 6, 7]),
    );
    expect(progress.targetDays, 0);
    expect(progress.activeDays, 0);
    expect(progress.progress, 1);
  });
}
