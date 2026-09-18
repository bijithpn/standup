/// Ties the two streak axes BreakMate tracks — break-taking consistency
/// ([CompanionStreakService]) and focus-day consistency ([FocusStreakService])
/// — together into one small comparison, rather than requiring the user to
/// remember both numbers from two different settings screens (Companion
/// Settings vs. the Focus tab). See the workflow-analysis plan doc §7/
/// PROJECT_ANALYSIS_AND_IMPROVEMENTS.md §3.1.
library;

/// How the two streaks currently relate to each other.
enum HabitsSyncStatus {
  /// Both streaks are 0 — nothing to compare yet.
  none,

  /// Both streaks are equal (and at least one day).
  inSync,

  /// The break streak is ahead of the focus streak.
  breakStreakAhead,

  /// The focus streak is ahead of the break streak.
  focusStreakAhead,
}

class HabitsSummary {
  final int breakStreakDays;
  final int focusStreakDays;

  const HabitsSummary({
    required this.breakStreakDays,
    required this.focusStreakDays,
  });

  int get gapDays => (breakStreakDays - focusStreakDays).abs();

  HabitsSyncStatus get syncStatus {
    if (breakStreakDays == 0 && focusStreakDays == 0) return HabitsSyncStatus.none;
    if (breakStreakDays == focusStreakDays) return HabitsSyncStatus.inSync;
    return breakStreakDays > focusStreakDays
        ? HabitsSyncStatus.breakStreakAhead
        : HabitsSyncStatus.focusStreakAhead;
  }

  /// One sentence describing how the two streaks relate — the thing a user
  /// would otherwise have to compute themselves from two separate screens.
  String describe() {
    switch (syncStatus) {
      case HabitsSyncStatus.none:
        return 'Take a break and log some focused work to start building both streaks.';
      case HabitsSyncStatus.inSync:
        return 'Your focus and break streaks are in sync at $breakStreakDays '
            'day${breakStreakDays == 1 ? '' : 's'}.';
      case HabitsSyncStatus.breakStreakAhead:
        return 'Your focus streak is $gapDays day${gapDays == 1 ? '' : 's'} '
            'behind your break streak.';
      case HabitsSyncStatus.focusStreakAhead:
        return 'Your break streak is $gapDays day${gapDays == 1 ? '' : 's'} '
            'behind your focus streak.';
    }
  }
}
