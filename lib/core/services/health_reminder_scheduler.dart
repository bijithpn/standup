import 'dart:math';

// Kinds of health nudges; extension below holds each kind's cadence and relief rules.
enum HealthReminderKind { eyeRest, blink, posture, hydration, stretch, standUp }

extension HealthReminderKindInfo on HealthReminderKind {
  String get typeName => switch (this) {
    HealthReminderKind.eyeRest => 'eyeblink',
    HealthReminderKind.blink => 'blink',
    HealthReminderKind.posture => 'posture',
    HealthReminderKind.hydration => 'hydration',
    HealthReminderKind.stretch => 'stretch',
    HealthReminderKind.standUp => 'standup',
  };

  // Base interval before workload/backoff/jitter adjustments.
  int get baselineMinutes => switch (this) {
    HealthReminderKind.eyeRest => 20,
    HealthReminderKind.blink => 12,
    HealthReminderKind.posture => 30,
    HealthReminderKind.stretch => 40,
    HealthReminderKind.hydration => 50,
    HealthReminderKind.standUp => 60,
  };

  // Idle time that counts as the user already doing it (e.g. 20s away rests eyes), resetting the timer.
  double get reliefIdleSeconds => switch (this) {
    HealthReminderKind.eyeRest => 20,
    HealthReminderKind.blink => 10,
    HealthReminderKind.posture => 120,
    HealthReminderKind.stretch => 120,
    HealthReminderKind.standUp => 120,
    HealthReminderKind.hydration => 300,
  };

  // Skip the reminder if a regular break is due within this window.
  Duration get breakAbsorbWindow => switch (this) {
    HealthReminderKind.eyeRest => const Duration(minutes: 3),
    HealthReminderKind.hydration => const Duration(minutes: 3),
    _ => const Duration(minutes: 5),
  };

  // Firing this kind also resets these (e.g. standing up covers posture and stretch).
  Set<HealthReminderKind> get alsoSatisfies => switch (this) {
    HealthReminderKind.eyeRest => {HealthReminderKind.blink},
    HealthReminderKind.standUp => {
      HealthReminderKind.posture,
      HealthReminderKind.stretch,
    },
    HealthReminderKind.stretch => {HealthReminderKind.posture},
    _ => const {},
  };
}

/// Scales reminder frequency by hours worked today: more frequent as the day goes on or with heavy context switching.
class WorkloadEstimator {
  const WorkloadEstimator._();

  static const double minFactor = 0.6;
  static const double maxFactor = 1.5;

  static double factor({
    required Duration workedToday,
    required bool highContextSwitching,
  }) {
    final hours = workedToday.inMinutes / 60;

    var f = hours < 1
        ? 1.25
        : hours < 3
        ? 1.0
        : hours < 6
        ? 0.85
        : 0.7;

    if (highContextSwitching) f *= 0.85;
    return f.clamp(minFactor, maxFactor);
  }
}

/// Decides which health reminder fires next, with per-kind jittered targets, ignore backoff, minimum gaps and an hourly cap.
class HealthReminderScheduler {
  // After a reminder fires, the user has this long to go idle (follow it) or it counts as ignored.
  static const Duration followWindow = Duration(seconds: 90);
  static const double followIdleSeconds = 15;

  static const Duration minGap = Duration(minutes: 4);
  static const Duration quietAfterBreak = Duration(minutes: 3);
  static const int maxIgnoredBackoffSteps = 4;
  static const Duration capWindow = Duration(hours: 1);

  static int hourlyCap(double workloadFactor) => workloadFactor < 0.85 ? 5 : 4;

  final Random _random;

  HealthReminderScheduler({Random? random}) : _random = random ?? Random();

  final Map<HealthReminderKind, int?> _targetSeconds = {};
  final Map<HealthReminderKind, int> _ignored = {};
  final List<DateTime> _recentFires = [];
  DateTime? _lastAnyFired;
  DateTime? _lastBreakEnded;

  HealthReminderKind? _awaitingFollow;
  DateTime? _awaitingSince;

  int ignoredStreak(HealthReminderKind kind) => _ignored[kind] ?? 0;

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

  // Target grows 25% per ignored reminder (up to 4 steps); jitter avoids predictable timing.
  int _pickTarget(
    HealthReminderKind kind,
    double activityRatio,
    double cadenceMultiplier,
  ) {
    final backoff = 1 + 0.25 * min(ignoredStreak(kind), maxIgnoredBackoffSteps);

    final jitter = 0.85 + _random.nextDouble() * 0.3;
    final minutes =
        kind.baselineMinutes *
        activityRatio.clamp(0.8, 1.2) *
        cadenceMultiplier *
        backoff *
        jitter;
    return (minutes * 60).round().clamp(60, 4 * 60 * 60);
  }

  void clearTarget(HealthReminderKind kind) => _targetSeconds[kind] = null;

  void onBreakCompleted(DateTime now, {bool long = false}) {
    _lastBreakEnded = now;
    for (final kind in HealthReminderKind.values) {
      if (kind == HealthReminderKind.hydration && !long) continue;
      clearTarget(kind);
    }
    _awaitingFollow = null;
  }

  /// Feeds idle time: clears targets for kinds the user already relieved and resolves follow/ignore of the last reminder.
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
        _ignored[awaiting] = 0;
        _awaitingFollow = null;
      } else if (since > followWindow) {
        _ignored[awaiting] = ignoredStreak(awaiting) + 1;
        _awaitingFollow = null;
      }
    }
    return relieved;
  }

  /// Returns the kind to fire now or null; overdue kinds are picked by weighted random so the most overdue is likeliest.
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

    final candidates = <HealthReminderKind, double>{};
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
      candidates[kind] = overdue + 120;
    });
    if (candidates.isEmpty) return null;

    final total = candidates.values.fold<double>(0, (a, b) => a + b);
    var roll = _random.nextDouble() * total;
    for (final entry in candidates.entries) {
      roll -= entry.value;
      if (roll <= 0) return entry.key;
    }
    return candidates.keys.last;
  }

  /// Records a fired reminder and returns the other kinds it satisfies; an unanswered previous reminder counts as ignored.
  Set<HealthReminderKind> markFired(HealthReminderKind kind, DateTime now) {
    _lastAnyFired = now;
    _recentFires.add(now);
    _targetSeconds[kind] = null;
    final covered = kind.alsoSatisfies;
    covered.forEach(clearTarget);

    if (_awaitingFollow != null && _awaitingFollow != kind) {
      _ignored[_awaitingFollow!] = ignoredStreak(_awaitingFollow!) + 1;
    }
    _awaitingFollow = kind;
    _awaitingSince = now;
    return covered;
  }
}
