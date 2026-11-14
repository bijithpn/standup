import 'dart:math';

/// Pluggable rules for when a long break is due, break length, focus interval and idle-based cycle reset.
abstract class BreakDeterminationStrategy {
  bool isLongBreakDue({
    required int completedShortBreaksInCycle,
    required Duration workElapsed,
    required Duration elapsedSinceLastLongBreak,
    required int repeatCycle,
    required int longBreakIntervalMinutes,
  });

  int determineBreakDurationSeconds({
    required bool isLongBreak,
    required int shortBreakDurationSeconds,
    required int longBreakDurationMinutes,
  });

  Duration determineFocusInterval({required int shortBreakIntervalMinutes});

  bool shouldResetCycleAfterIdle({
    required Duration idleDuration,
    required int resetAfterMinutes,
  });
}

/// Long break after N short breaks (the repeat cycle) or when the long-break interval has elapsed, whichever comes first.
class RepeatCycleBreakStrategy implements BreakDeterminationStrategy {
  final int defaultRepeatCycle;

  const RepeatCycleBreakStrategy({this.defaultRepeatCycle = 4});

  @override
  bool isLongBreakDue({
    required int completedShortBreaksInCycle,
    required Duration workElapsed,
    required Duration elapsedSinceLastLongBreak,
    required int repeatCycle,
    required int longBreakIntervalMinutes,
  }) {
    // Fall back to ~1 short break per 20 min of the long interval when no cycle is configured.
    final effectiveCycle = repeatCycle > 0
        ? repeatCycle
        : (longBreakIntervalMinutes > 0
              ? max(1, (longBreakIntervalMinutes / 20).round())
              : defaultRepeatCycle);

    if (completedShortBreaksInCycle >= effectiveCycle) {
      return true;
    }

    if (longBreakIntervalMinutes > 0 &&
        elapsedSinceLastLongBreak >=
            Duration(minutes: longBreakIntervalMinutes)) {
      return true;
    }

    return false;
  }

  @override
  int determineBreakDurationSeconds({
    required bool isLongBreak,
    required int shortBreakDurationSeconds,
    required int longBreakDurationMinutes,
  }) {
    if (isLongBreak) {
      // Floors keep breaks long enough to be useful (60s long, 15s short).
      return max(60, longBreakDurationMinutes * 60);
    }
    return max(15, shortBreakDurationSeconds);
  }

  @override
  Duration determineFocusInterval({required int shortBreakIntervalMinutes}) {
    return Duration(minutes: max(1, shortBreakIntervalMinutes));
  }

  @override
  bool shouldResetCycleAfterIdle({
    required Duration idleDuration,
    required int resetAfterMinutes,
  }) {
    if (resetAfterMinutes <= 0) return false;
    return idleDuration >= Duration(minutes: resetAfterMinutes);
  }
}

/// Delegates to [innerStrategy] and adds idle awareness: long away time can count as a break.
class IdleTimeBreakStrategy implements BreakDeterminationStrategy {
  final BreakDeterminationStrategy innerStrategy;

  const IdleTimeBreakStrategy({
    this.innerStrategy = const RepeatCycleBreakStrategy(),
  });

  @override
  bool isLongBreakDue({
    required int completedShortBreaksInCycle,
    required Duration workElapsed,
    required Duration elapsedSinceLastLongBreak,
    required int repeatCycle,
    required int longBreakIntervalMinutes,
  }) {
    return innerStrategy.isLongBreakDue(
      completedShortBreaksInCycle: completedShortBreaksInCycle,
      workElapsed: workElapsed,
      elapsedSinceLastLongBreak: elapsedSinceLastLongBreak,
      repeatCycle: repeatCycle,
      longBreakIntervalMinutes: longBreakIntervalMinutes,
    );
  }

  @override
  int determineBreakDurationSeconds({
    required bool isLongBreak,
    required int shortBreakDurationSeconds,
    required int longBreakDurationMinutes,
  }) {
    return innerStrategy.determineBreakDurationSeconds(
      isLongBreak: isLongBreak,
      shortBreakDurationSeconds: shortBreakDurationSeconds,
      longBreakDurationMinutes: longBreakDurationMinutes,
    );
  }

  @override
  Duration determineFocusInterval({required int shortBreakIntervalMinutes}) {
    return innerStrategy.determineFocusInterval(
      shortBreakIntervalMinutes: shortBreakIntervalMinutes,
    );
  }

  @override
  bool shouldResetCycleAfterIdle({
    required Duration idleDuration,
    required int resetAfterMinutes,
  }) {
    if (resetAfterMinutes <= 0) return false;
    return idleDuration >= Duration(minutes: resetAfterMinutes);
  }

  /// Away time counts as a break if it lasts at least the break length (minimum 2 min).
  bool doesAwayTimeQualifyAsBreak({
    required Duration awayDuration,
    required int minBreakMinutes,
  }) {
    return awayDuration >= Duration(minutes: max(2, minBreakMinutes));
  }
}
