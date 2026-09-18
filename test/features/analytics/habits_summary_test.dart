// Coverage for tying the break streak and focus streak together (plan doc
// §7/PROJECT_ANALYSIS_AND_IMPROVEMENTS.md §3.1).
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/habits_summary.dart';

void main() {
  group('syncStatus', () {
    test('is none when both streaks are zero', () {
      const summary = HabitsSummary(breakStreakDays: 0, focusStreakDays: 0);
      expect(summary.syncStatus, HabitsSyncStatus.none);
    });

    test('is inSync when both streaks match and are non-zero', () {
      const summary = HabitsSummary(breakStreakDays: 5, focusStreakDays: 5);
      expect(summary.syncStatus, HabitsSyncStatus.inSync);
    });

    test('is breakStreakAhead when the break streak leads', () {
      const summary = HabitsSummary(breakStreakDays: 7, focusStreakDays: 3);
      expect(summary.syncStatus, HabitsSyncStatus.breakStreakAhead);
      expect(summary.gapDays, 4);
    });

    test('is focusStreakAhead when the focus streak leads', () {
      const summary = HabitsSummary(breakStreakDays: 2, focusStreakDays: 6);
      expect(summary.syncStatus, HabitsSyncStatus.focusStreakAhead);
      expect(summary.gapDays, 4);
    });
  });

  group('describe', () {
    test('prompts to start when both are zero', () {
      const summary = HabitsSummary(breakStreakDays: 0, focusStreakDays: 0);
      expect(summary.describe(), contains('start building'));
    });

    test('describes an in-sync streak', () {
      const summary = HabitsSummary(breakStreakDays: 4, focusStreakDays: 4);
      expect(summary.describe(), contains('in sync at 4 days'));
    });

    test('describes the focus streak lagging behind the break streak', () {
      const summary = HabitsSummary(breakStreakDays: 8, focusStreakDays: 5);
      expect(summary.describe(), contains('focus streak is 3 days behind'));
    });

    test('describes the break streak lagging behind the focus streak', () {
      const summary = HabitsSummary(breakStreakDays: 1, focusStreakDays: 4);
      expect(summary.describe(), contains('break streak is 3 days behind'));
    });

    test('uses singular "day" for a one-day streak', () {
      const summary = HabitsSummary(breakStreakDays: 1, focusStreakDays: 1);
      expect(summary.describe(), contains('in sync at 1 day.'));
    });
  });
}
