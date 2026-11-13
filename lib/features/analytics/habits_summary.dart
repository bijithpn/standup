library;

enum HabitsSyncStatus { none, inSync, breakStreakAhead, focusStreakAhead }

/// Compares break-streak and focus-streak lengths to produce a one-line sync message.
class HabitsSummary {
  final int breakStreakDays;
  final int focusStreakDays;

  const HabitsSummary({
    required this.breakStreakDays,
    required this.focusStreakDays,
  });

  int get gapDays => (breakStreakDays - focusStreakDays).abs();

  HabitsSyncStatus get syncStatus {
    if (breakStreakDays == 0 && focusStreakDays == 0) {
      return HabitsSyncStatus.none;
    }
    if (breakStreakDays == focusStreakDays) return HabitsSyncStatus.inSync;
    return breakStreakDays > focusStreakDays
        ? HabitsSyncStatus.breakStreakAhead
        : HabitsSyncStatus.focusStreakAhead;
  }

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
