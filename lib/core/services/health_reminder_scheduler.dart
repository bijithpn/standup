import 'dart:math';

enum HealthReminderKind { eyeRest, posture, hydration, stretch, standUp }

extension HealthReminderKindInfo on HealthReminderKind {
  /// Name carried by `HealthReminderEvent.reminderType` and the overlay.
  String get typeName => switch (this) {
    HealthReminderKind.eyeRest => 'eyeblink',
    HealthReminderKind.posture => 'posture',
    HealthReminderKind.hydration => 'hydration',
    HealthReminderKind.stretch => 'stretch',
    HealthReminderKind.standUp => 'standup',
  };

  /// Minutes of active work between reminders on a normal day.
  int get baselineMinutes => switch (this) {
    HealthReminderKind.eyeRest => 20, // the 20-20-20 rule
    HealthReminderKind.posture => 30,
    HealthReminderKind.stretch => 40,
    HealthReminderKind.hydration => 50,
    HealthReminderKind.standUp => 60,
  };

  /// Idle time (no keyboard/mouse) that counts as the user having done it.
  double get reliefIdleSeconds => switch (this) {
    HealthReminderKind.eyeRest => 20,
    HealthReminderKind.posture => 120,
    HealthReminderKind.stretch => 120,
    HealthReminderKind.standUp => 120,
    HealthReminderKind.hydration => 300, // time to fetch a glass of water
  };

  /// How close a scheduled break may be before it covers this reminder.
  Duration get breakAbsorbWindow => switch (this) {
    HealthReminderKind.eyeRest => const Duration(minutes: 3),
    HealthReminderKind.hydration => const Duration(minutes: 3),
    _ => const Duration(minutes: 5),
  };

  /// Reminders that this one also satisfies (standing up fixes posture, etc.).
  Set<HealthReminderKind> get alsoSatisfies => switch (this) {
    HealthReminderKind.standUp => {
      HealthReminderKind.posture,
      HealthReminderKind.stretch,
    },
    HealthReminderKind.stretch => {HealthReminderKind.posture},
    _ => const {},
  };
}

/// Turns what we know about how hard the user is working into a multiplier on
/// reminder intervals: below 1 means "remind more often", above 1 "less".
class WorkloadEstimator {
  const WorkloadEstimator._();

  static const double minFactor = 0.6;
  static const double maxFactor = 1.5;

  static double factor({
    required Duration workedToday,
    required bool highContextSwitching,
  }) {
    final hours = workedToday.inMinutes / 60;
    // Fatigue builds through the day; the first hour is a gentle warm-up.
    var f = hours < 1
        ? 1.25
        : hours < 3
        ? 1.0
        : hours < 6
        ? 0.85
        : 0.7;
    // Constantly switching between apps is a busy, mentally heavy stretch.
    if (highContextSwitching) f *= 0.85;
    return f.clamp(minFactor, maxFactor);
  }
}

/// Decides *when* a health reminder should appear. Pure logic (no timers, no
/// I/O) so every rule is unit-testable; [TimerEngine] feeds it the facts once
/// per tick and acts on the answer.
///
///  * **Workload-aware.** The busier the day (long hours, constant app
///    switching) the more often reminders come; light days get fewer.
///  * **Random, not mechanical.** Each interval is jittered ±15%.
///  * **Real relief counts.** Stepping away resets the matching reminders; a
///    completed break resets all but hydration (a long break resets that too);
///    a skipped break resets nothing.
///  * **Breaks absorb reminders** that would land just before them.
///  * **Never in the way.** Meetings, calls and presentations defer them.
///  * **No stacking.** A minimum gap between reminders, a quiet period after a
///    break, and an hourly cap (higher on heavy days) keep it from nagging.
///  * **Learns from the user.** Reminders that keep being ignored are spaced
///    further apart (up to 2x); acting on one restores the normal cadence.
class HealthReminderScheduler {
  /// A reminder is followed if the user steps away this soon after it.
  static const Duration followWindow = Duration(seconds: 90);
  static const double followIdleSeconds = 15;

  static const Duration minGap = Duration(minutes: 4);
  static const Duration quietAfterBreak = Duration(minutes: 3);
  static const int maxIgnoredBackoffSteps = 4;
  static const Duration capWindow = Duration(hours: 1);

  /// Most reminders in any rolling hour; heavy days allow one more.
  static int hourlyCap(double workloadFactor) => workloadFactor < 0.85 ? 5 : 4;

  final Random _random;

  HealthReminderScheduler({Random? random}) : _random = random ?? Random();

  final Map<HealthReminderKind, int?> _targetSeconds = {};
  final Map<HealthReminderKind, int> _ignored = {};
  final List<DateTime> _recentFires = [];
  DateTime? _lastAnyFired;
  DateTime? _lastBreakEnded;

  /// Reminder awaiting a sign that the user acted on it.
  HealthReminderKind? _awaitingFollow;
  DateTime? _awaitingSince;

  int ignoredStreak(HealthReminderKind kind) => _ignored[kind] ?? 0;

  /// Seconds of active work (before workload scaling) after which [kind] is
  /// due.
  int targetSeconds(
    HealthReminderKind kind, {
    double activityRatio = 1.0,
    double cadenceMultiplier = 1.0,
  }) {
    return _targetSeconds[kind] ??= _pickTarget(
      kind,
      activityRatio,
      cadenceMultiplier,
    );
  }

  int _pickTarget(
    HealthReminderKind kind,
    double activityRatio,
    double cadenceMultiplier,
  ) {
    // Back off (up to 2x) while the user keeps ignoring this reminder.
    final backoff = 1 + 0.25 * min(ignoredStreak(kind), maxIgnoredBackoffSteps);
    // ±15% jitter so it doesn't feel mechanical.
    final jitter = 0.85 + _random.nextDouble() * 0.3;
    final minutes =
        kind.baselineMinutes *
        activityRatio.clamp(0.8, 1.2) *
        cadenceMultiplier *
        backoff *
        jitter;
    return (minutes * 60).round().clamp(60, 4 * 60 * 60);
  }

  /// Forgets the chosen target so the next one is computed fresh.
  void clearTarget(HealthReminderKind kind) => _targetSeconds[kind] = null;

  /// A break was completed (not skipped).
  void onBreakCompleted(DateTime now, {bool long = false}) {
    _lastBreakEnded = now;
    for (final kind in HealthReminderKind.values) {
      if (kind == HealthReminderKind.hydration && !long) continue;
      clearTarget(kind);
    }
    _awaitingFollow = null;
  }

  /// Reports how long the user has been without input. Returns the kinds whose
  /// elapsed counters should be reset because the user got real relief, and
  /// updates the "did they act on the last reminder" learning.
  Set<HealthReminderKind> onIdleSample(double idleSeconds, DateTime now) {
    final relieved = <HealthReminderKind>{
      for (final k in HealthReminderKind.values)
        if (idleSeconds >= k.reliefIdleSeconds) k,
    };
    relieved.forEach(clearTarget);

    final awaiting = _awaitingFollow;
    if (awaiting != null) {
      final since = now.difference(_awaitingSince!);
      if (idleSeconds >= followIdleSeconds && since <= followWindow) {
        _ignored[awaiting] = 0; // they acted on it
        _awaitingFollow = null;
      } else if (since > followWindow) {
        _ignored[awaiting] = ignoredStreak(awaiting) + 1;
        _awaitingFollow = null;
      }
    }
    return relieved;
  }

  /// Returns the reminder to show now, or null. [elapsedSeconds] is active
  /// work time since the last relief for each enabled kind (omit disabled
  /// kinds). [untilNextBreak] is null when no break is scheduled.
  /// [workloadFactor] comes from [WorkloadEstimator].
  HealthReminderKind? nextDue({
    required DateTime now,
    required Map<HealthReminderKind, int> elapsedSeconds,
    required Duration? untilNextBreak,
    required bool blockedByContext,
    double activityRatio = 1.0,
    double cadenceMultiplier = 1.0,
    double workloadFactor = 1.0,
  }) {
    if (blockedByContext) return null;
    final lastBreak = _lastBreakEnded;
    if (lastBreak != null && now.difference(lastBreak) < quietAfterBreak) {
      return null;
    }
    final lastAny = _lastAnyFired;
    if (lastAny != null && now.difference(lastAny) < minGap) return null;

    _recentFires.removeWhere((t) => now.difference(t) >= capWindow);
    if (_recentFires.length >= hourlyCap(workloadFactor)) return null;

    HealthReminderKind? best;
    double bestOverdue = -1;
    elapsedSeconds.forEach((kind, elapsed) {
      final target =
          targetSeconds(
            kind,
            activityRatio: activityRatio,
            cadenceMultiplier: cadenceMultiplier,
          ) *
          workloadFactor;
      final overdue = elapsed - target;
      if (overdue < 0) return;

      if (untilNextBreak != null && untilNextBreak <= kind.breakAbsorbWindow) {
        return;
      }

      if (overdue > bestOverdue) {
        best = kind;
        bestOverdue = overdue;
      }
    });
    return best;
  }

  /// Call when a reminder is actually shown. Returns the kinds whose elapsed
  /// counters should also reset because this reminder covers them.
  Set<HealthReminderKind> markFired(HealthReminderKind kind, DateTime now) {
    _lastAnyFired = now;
    _recentFires.add(now);
    _targetSeconds[kind] = null;
    final covered = kind.alsoSatisfies;
    covered.forEach(clearTarget);
    // If a previous reminder was never acted on, count it as ignored.
    if (_awaitingFollow != null && _awaitingFollow != kind) {
      _ignored[_awaitingFollow!] = ignoredStreak(_awaitingFollow!) + 1;
    }
    _awaitingFollow = kind;
    _awaitingSince = now;
    return covered;
  }
}
