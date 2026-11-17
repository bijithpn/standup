import 'package:breakmate/core/services/timer_repository.dart';
import 'package:breakmate/core/services/timer_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'timer_engine_drift_test.dart' show FakeStorageService;

void main() {
  test(
    'pending return choice and exact progress survive repository restore',
    () {
      final repo = TimerRepository(FakeStorageService());
      final state = TimerStateData()
        ..state = TimerState.paused
        ..awaitingReturnDecision = true
        ..pausedForInactivity = true
        ..workElapsed = const Duration(minutes: 14, seconds: 43)
        ..totalWorkToday = const Duration(hours: 2)
        ..countdownSeconds = 317;
      repo.save(
        state,
        shortBreakIntervalMinutes: 20,
        shortBreakDurationSeconds: 20,
        preBreakWarningSeconds: 60,
        longBreakIntervalMinutes: 60,
        longBreakDurationMinutes: 5,
        pauseTimerAfterMinutes: 15,
        resetTimerAfterMinutes: 15,
      );
      final restored = TimerStateData();
      repo.restore(
        restored,
        defaultShortBreakIntervalMinutes: 20,
        defaultShortBreakDurationSeconds: 20,
        defaultPreBreakWarningSeconds: 60,
        defaultLongBreakIntervalMinutes: 60,
        defaultLongBreakDurationMinutes: 5,
        defaultPauseTimerAfterMinutes: 15,
        defaultResetTimerAfterMinutes: 15,
        onSettingsRestored: (_, _, _, _, _, _, _) {},
      );
      expect(restored.state, TimerState.paused);
      expect(restored.awaitingReturnDecision, isTrue);
      expect(restored.pausedForInactivity, isTrue);
      expect(restored.isManuallyPaused, isFalse);
      expect(restored.workElapsed, const Duration(minutes: 14, seconds: 43));
      expect(restored.countdownSeconds, 317);
      expect(restored.totalWorkToday, const Duration(hours: 2));
    },
  );
}
