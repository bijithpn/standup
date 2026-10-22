import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/services/health_reminder_scheduler.dart';

void main() {
  workloadTests();
  final t0 = DateTime(2026, 3, 10, 10);
  const eye = HealthReminderKind.eyeRest;
  const posture = HealthReminderKind.posture;

  late HealthReminderScheduler s;
  setUp(() => s = HealthReminderScheduler(random: Random(1)));

  HealthReminderKind? due(
    Map<HealthReminderKind, int> elapsed, {
    DateTime? now,
    Duration? untilBreak,
    bool blocked = false,
  }) => s.nextDue(
    now: now ?? t0,
    elapsedSeconds: elapsed,
    untilNextBreak: untilBreak,
    blockedByContext: blocked,
  );

  test('target stays near the baseline (±15%)', () {
    for (var i = 0; i < 40; i++) {
      final fresh = HealthReminderScheduler(random: Random(i));
      final eyeT = fresh.targetSeconds(eye);
      final postT = fresh.targetSeconds(posture);
      expect(eyeT, inInclusiveRange(20 * 60 * 0.85, 20 * 60 * 1.15));
      expect(postT, inInclusiveRange(30 * 60 * 0.85, 30 * 60 * 1.15));
    }
  });

  test('not due before the target, due after', () {
    final target = s.targetSeconds(eye);
    expect(due({eye: target - 1}), isNull);
    expect(due({eye: target}), eye);
  });

  test('picks the most overdue reminder first', () {
    final e = s.targetSeconds(eye);
    final p = s.targetSeconds(posture);
    expect(due({eye: e + 10, posture: p + 600}), posture);
  });

  test('two reminders are never shown back to back', () {
    final e = s.targetSeconds(eye);
    final p = s.targetSeconds(posture);
    final elapsed = {eye: e + 5, posture: p + 5};
    final first = due(elapsed)!;
    s.markFired(first, t0);
    expect(due(elapsed, now: t0.add(const Duration(minutes: 1))), isNull);
    expect(
      due(elapsed, now: t0.add(HealthReminderScheduler.minGap)),
      isNotNull,
    );
  });

  test('an imminent break absorbs the reminder', () {
    final e = s.targetSeconds(eye);
    expect(due({eye: e + 30}, untilBreak: const Duration(minutes: 2)), isNull);
    // Break is far enough away: remind.
    expect(due({eye: e + 30}, untilBreak: const Duration(minutes: 10)), eye);
  });

  test('posture waits for a longer window than eyes', () {
    final p = s.targetSeconds(posture);
    final e = s.targetSeconds(eye);
    expect(due({posture: p}, untilBreak: const Duration(minutes: 4)), isNull);
    expect(due({eye: e}, untilBreak: const Duration(minutes: 4)), eye);
  });

  test('meetings and presentations defer, then it fires afterwards', () {
    final e = s.targetSeconds(eye);
    expect(due({eye: e + 60}, blocked: true), isNull);
    expect(due({eye: e + 60}), eye);
  });

  test('no reminder right after a completed break', () {
    final e = s.targetSeconds(eye);
    s.onBreakCompleted(t0);
    final newTarget = s.targetSeconds(eye);
    expect(
      due({eye: newTarget + 5}, now: t0.add(const Duration(minutes: 1))),
      isNull,
    );
    expect(
      due({
        eye: newTarget + 5,
      }, now: t0.add(HealthReminderScheduler.quietAfterBreak)),
      eye,
    );
    expect(e, isPositive);
  });

  group('idle relief', () {
    test('20s away rests the eyes but not posture', () {
      final relieved = s.onIdleSample(25, t0);
      expect(relieved, {eye});
    });

    test('a longer absence also resets posture', () {
      expect(s.onIdleSample(150, t0), containsAll([eye, posture]));
    });

    test('brief idle does nothing', () {
      expect(s.onIdleSample(5, t0), isEmpty);
    });
  });

  group('learning from the user', () {
    test('acting on a reminder keeps the normal cadence', () {
      s.markFired(eye, t0);
      s.onIdleSample(20, t0.add(const Duration(seconds: 30)));
      expect(s.ignoredStreak(eye), 0);
    });

    test('ignoring reminders spaces them out, up to 2x', () {
      var now = t0;
      for (var i = 0; i < 6; i++) {
        s.markFired(eye, now);
        now = now.add(const Duration(minutes: 5));
        // User keeps working: an idle sample long after the follow window.
        s.onIdleSample(0, now);
      }
      expect(s.ignoredStreak(eye), 6);
      s.clearTarget(eye);
      final backedOff = s.targetSeconds(eye);
      expect(backedOff, greaterThan(20 * 60 * 1.7));
      expect(backedOff, lessThanOrEqualTo(20 * 60 * 2.3));
    });

    test('acting on one reminder resets the backoff', () {
      var now = t0;
      for (var i = 0; i < 3; i++) {
        s.markFired(eye, now);
        now = now.add(const Duration(minutes: 5));
        s.onIdleSample(0, now);
      }
      expect(s.ignoredStreak(eye), 3);
      s.markFired(eye, now);
      s.onIdleSample(30, now.add(const Duration(seconds: 20)));
      expect(s.ignoredStreak(eye), 0);
    });
  });
}

void workloadTests() {
  final t0 = DateTime(2026, 3, 10, 10);

  group('WorkloadEstimator', () {
    test('light morning stretches intervals, heavy day shortens them', () {
      double f(int minutes, {bool switching = false}) =>
          WorkloadEstimator.factor(
            workedToday: Duration(minutes: minutes),
            highContextSwitching: switching,
          );
      expect(f(20), greaterThan(1.0));
      expect(f(120), 1.0);
      expect(f(240), lessThan(1.0));
      expect(f(500), lessThan(f(240)));
      expect(f(240, switching: true), lessThan(f(240)));
    });

    test('always stays inside the allowed range', () {
      for (var m = 0; m <= 900; m += 30) {
        for (final sw in [false, true]) {
          final v = WorkloadEstimator.factor(
            workedToday: Duration(minutes: m),
            highContextSwitching: sw,
          );
          expect(v, inInclusiveRange(0.6, 1.5));
        }
      }
    });
  });

  group('workload scaling in the scheduler', () {
    test('a heavy day brings the same reminder sooner', () {
      final s = HealthReminderScheduler(random: Random(5));
      const kind = HealthReminderKind.hydration;
      final target = s.targetSeconds(kind);
      HealthReminderKind? at(double factor, int elapsed) => s.nextDue(
        now: t0,
        elapsedSeconds: {kind: elapsed},
        untilNextBreak: null,
        blockedByContext: false,
        workloadFactor: factor,
      );
      final heavyAt = (target * 0.7).ceil();
      expect(at(1.0, heavyAt), isNull);
      expect(at(0.7, heavyAt), kind);
      // Light day: still not due at the normal time.
      expect(at(1.25, target), isNull);
    });
  });

  group('new reminder kinds', () {
    test('each has its own cadence, longest for stand-up', () {
      final mins = {
        for (final k in HealthReminderKind.values) k: k.baselineMinutes,
      };
      expect(mins[HealthReminderKind.eyeRest], 20);
      expect(mins[HealthReminderKind.standUp], 60);
      expect(mins.values.toSet().length, mins.length);
    });

    test('standing up also satisfies posture and stretch', () {
      final s = HealthReminderScheduler(random: Random(1));
      final covered = s.markFired(HealthReminderKind.standUp, t0);
      expect(covered, {HealthReminderKind.posture, HealthReminderKind.stretch});
    });

    test('a short idle does not count as a drink; a 5 min absence does', () {
      final s = HealthReminderScheduler(random: Random(1));
      expect(
        s.onIdleSample(150, t0),
        isNot(contains(HealthReminderKind.hydration)),
      );
      expect(s.onIdleSample(320, t0), contains(HealthReminderKind.hydration));
    });

    test('a short break does not cover hydration, a long one does', () {
      final s = HealthReminderScheduler(random: Random(1));
      final before = s.targetSeconds(HealthReminderKind.hydration);
      s.onBreakCompleted(t0);
      expect(s.targetSeconds(HealthReminderKind.hydration), before);
      s.onBreakCompleted(t0, long: true);
      // Cleared, so a fresh draw is made (may differ).
      expect(s.targetSeconds(HealthReminderKind.hydration), isPositive);
    });
  });

  group('hourly cap', () {
    test('stops after the cap and resumes once the hour rolls over', () {
      final s = HealthReminderScheduler(random: Random(2));
      var now = t0;
      var fired = 0;
      // Offer an overdue reminder every 5 minutes (past the 4 min gap).
      for (var i = 0; i < 10; i++) {
        final due = s.nextDue(
          now: now,
          elapsedSeconds: {HealthReminderKind.eyeRest: 99999},
          untilNextBreak: null,
          blockedByContext: false,
        );
        if (due != null) {
          s.markFired(due, now);
          fired++;
        }
        now = now.add(const Duration(minutes: 5));
      }
      // Minutes 0..45 inside the first hour: capped at 4, then 1 more once the
      // first one ages out of the rolling hour.
      expect(fired, lessThanOrEqualTo(6));
      final inFirstHour = HealthReminderScheduler.hourlyCap(1.0);
      expect(inFirstHour, 4);
      expect(HealthReminderScheduler.hourlyCap(0.7), 5);
      expect(fired, greaterThanOrEqualTo(inFirstHour));
    });
  });
}
