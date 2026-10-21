import 'dart:math';

/// Protocol / Strategy interface for determining break timing, break type
/// (short vs. long break), cycle progression, and idle resets.
/// Forensically replicated from DeskRest's `Domain.BreakDeterminationStrategy`.
abstract class BreakDeterminationStrategy {
  /// Evaluates whether the upcoming break must be a Long Break.
  bool isLongBreakDue({
    required int completedShortBreaksInCycle,
    required Duration workElapsed,
    required Duration elapsedSinceLastLongBreak,
    required int repeatCycle,
    required int longBreakIntervalMinutes,
  });

  /// Determines the active break duration in seconds.
  int determineBreakDurationSeconds({
    required bool isLongBreak,
    required int shortBreakDurationSeconds,
    required int longBreakDurationMinutes,
  });

  /// Determines the active focus duration before the next break.
  Duration determineFocusInterval({
    required int shortBreakIntervalMinutes,
  });

  /// Evaluates whether user inactivity / idle time should reset the break cycle
  /// counter (so returning users start fresh with short breaks).
  bool shouldResetCycleAfterIdle({
    required Duration idleDuration,
    required int resetAfterMinutes,
  });
}

/// DeskRest's primary cycle-based determination strategy.
/// Triggers a long break every [repeatCycle] short breaks (e.g. every 4th break),
/// with wall-clock elapsed time fallback.
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
    final effectiveCycle = repeatCycle > 0
        ? repeatCycle
        : (longBreakIntervalMinutes > 0
            ? max(1, (longBreakIntervalMinutes / 20).round())
            : defaultRepeatCycle);

    // 1. Cycle count check: If user completed enough short breaks in this cycle
    if (completedShortBreaksInCycle >= effectiveCycle) {
      return true;
    }

    // 2. Wall-clock interval fallback: If long break interval elapsed
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
      return max(60, longBreakDurationMinutes * 60);
    }
    return max(15, shortBreakDurationSeconds);
  }

  @override
  Duration determineFocusInterval({
    required int shortBreakIntervalMinutes,
  }) {
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

/// DeskRest's idle-time aware determination strategy.
/// Monitors idle / away periods and decides whether the user's away time
/// should count toward a break, reset the cycle, or defer reminders.
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
  Duration determineFocusInterval({
    required int shortBreakIntervalMinutes,
  }) {
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

  /// Evaluates whether an away duration (e.g. stepping away from computer for 15m)
  /// qualifies as an achieved break that can advance or reset the cycle.
  bool doesAwayTimeQualifyAsBreak({
    required Duration awayDuration,
    required int minBreakMinutes,
  }) {
    return awayDuration >= Duration(minutes: max(2, minBreakMinutes));
  }
}
