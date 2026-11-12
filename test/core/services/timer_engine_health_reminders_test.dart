import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/services/health_reminder_scheduler.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/services/timer_repository.dart';
import 'package:breakmate/core/services/timer_state.dart';
import 'package:breakmate/features/settings/settings_model.dart';

import '../../helpers/in_memory_settings_repository.dart';
import 'timer_engine_drift_test.dart'
    show FakeStorageService, MockCalendarService, MockSmartDetectionService;

void main() {
  final sl = GetIt.instance;
  late InMemorySettingsRepository settings;
  late MockCalendarService calendar;
  late MockSmartDetectionService detection;
  late List<HealthReminderEvent> reminders;
  StreamSubscription<AppEvent>? sub;

  setUp(() {
    sl.reset();
    sl.registerSingleton<StorageService>(FakeStorageService());
    settings = InMemorySettingsRepository(
      const SettingsModel(
        eyeBlinkReminderEnabled: true,
        postureReminderEnabled: true,
        // Long break interval so breaks don't interfere unless a test wants.
        shortBreakIntervalMinutes: 90,
      ),
    );
    calendar = MockCalendarService();
    detection = MockSmartDetectionService();
    when(() => calendar.isMeetingActive()).thenAnswer((_) async => false);
    when(() => detection.isVideoCallActive).thenReturn(false);
    when(() => detection.isVideoPlaying).thenReturn(false);
    reminders = [];
    sub = EventBus.instance.stream.listen((e) {
      if (e is HealthReminderEvent) reminders.add(e);
    });
  });

  tearDown(() => sub?.cancel());

  int seed = 0;

  TimerEngine buildEngine() => TimerEngine(
    settingsRepository: settings,
    smartDetectionService: detection,
    calendarService: calendar as CalendarService,
    eventBus: EventBus.instance,
    healthScheduler: HealthReminderScheduler(random: Random(seed)),
  );

  /// Starts an engine in the "normal workload" band (2h already worked),
  /// where intervals are exactly the baselines.
  TimerEngine newEngine({Duration worked = const Duration(hours: 2)}) {
    final engine = buildEngine();
    engine.stateData.totalWorkToday = worked;
    return engine;
  }

  void run(FakeAsync async, Duration d) {
    async.elapse(d);
    async.flushMicrotasks();
  }

  for (var s = 0; s < 15; s++) {
    test(
      'eye reminder arrives around 20-27 minutes, posture follows (seed $s)',
      () {
        seed = s;
        fakeAsync((async) {
          final engine = newEngine()..startTimers();
          run(async, const Duration(minutes: 17));
          expect(reminders, isEmpty);
          // A 90-minute break interval stretches the 20-minute baseline by the
          // maximum 20% (24 min, up to 27.6 with jitter).
          run(async, const Duration(minutes: 11)); // 28 min
          expect(reminders.map((r) => r.reminderType), ['eyeblink']);
          // Posture is due by 41.4 min at the latest; eye rest may fire again
          // first, and reminders are spaced at least 4 minutes apart.
          run(async, const Duration(minutes: 25)); // 53 min
          final types = reminders.map((r) => r.reminderType).toList();
          expect(types.first, 'eyeblink');
          expect(types, contains('posture'));
          engine.dispose();
        });
      },
    );
  }

  test('stepping away resets the eye timer instead of reminding', () {
    fakeAsync((async) {
      final engine = newEngine()..startTimers();
      run(async, const Duration(minutes: 15));
      engine.reportIdleSeconds(30); // looked away for 30s
      run(async, const Duration(minutes: 15)); // only 15 min since
      expect(reminders.where((r) => r.reminderType == 'eyeblink'), isEmpty);
      engine.dispose();
    });
  });

  test('a completed break resets both, a skipped one resets neither', () {
    fakeAsync((async) {
      final engine = newEngine()..startTimers();
      run(async, const Duration(minutes: 15));
      engine.triggerBreakNow();
      engine.finishBreak(skipped: true);
      async.flushMicrotasks();
      expect(engine.stateData.eyeBlinkElapsedSeconds, greaterThan(14 * 60));

      engine.triggerBreakNow();
      engine.finishBreak(skipped: false);
      async.flushMicrotasks();
      expect(engine.stateData.eyeBlinkElapsedSeconds, 0);
      expect(engine.stateData.postureElapsedSeconds, 0);
      engine.dispose();
    });
  });

  test('disabled reminders never fire', () {
    fakeAsync((async) {
      settings.save(
        settings.currentSettings.copyWith(
          eyeBlinkReminderEnabled: false,
          postureReminderEnabled: false,
        ),
      );
      final engine = newEngine()..startTimers();
      run(async, const Duration(hours: 1));
      expect(reminders, isEmpty);
      engine.dispose();
    });
  });

  test('reminder is held back while a video call is active, then fires', () {
    fakeAsync((async) {
      var inCall = true;
      when(() => detection.isVideoCallActive).thenAnswer((_) => inCall);
      settings.save(settings.currentSettings.copyWith(detectVideoCalls: true));
      final engine = newEngine()..startTimers();
      run(async, const Duration(minutes: 30));
      expect(reminders.where((r) => r.reminderType == 'eyeblink'), isEmpty);
      inCall = false;
      run(async, const Duration(seconds: 5));
      expect(reminders.where((r) => r.reminderType == 'eyeblink'), isNotEmpty);
      engine.dispose();
    });
  });

  test('one switch turns on every reminder kind, shown at varied times', () {
    final kinds = <String>{};
    for (var s = 0; s < 6; s++) {
      seed = s;
      fakeAsync((async) {
        reminders.clear();
        settings.save(
          settings.currentSettings.copyWith(healthRemindersEnabled: true),
        );
        final engine = newEngine()..startTimers();
        run(async, const Duration(hours: 4));
        kinds.addAll(reminders.map((r) => r.reminderType));
        // Never more than the hourly cap (5 on busy days) over 4 hours.
        expect(reminders.length, lessThanOrEqualTo(20));
        engine.dispose();
      });
    }
    expect(kinds.length, greaterThanOrEqualTo(3));
    expect(kinds, contains('eyeblink'));
  });

  test('a busier day produces more reminders than a light one', () {
    int countFor(Duration alreadyWorked) {
      var count = 0;
      fakeAsync((async) {
        reminders.clear();
        settings.save(
          settings.currentSettings.copyWith(healthRemindersEnabled: true),
        );
        final engine = newEngine(worked: alreadyWorked)..startTimers();
        run(async, const Duration(minutes: 120));
        count = reminders.length;
        engine.dispose();
      });
      return count;
    }

    expect(
      countFor(const Duration(hours: 7)),
      greaterThan(countFor(Duration.zero)),
    );
  });

  test('reminder counters are saved and restored for every kind', () {
    final storage = sl<StorageService>();
    final repo = TimerRepository(storage);
    final state = TimerStateData()
      ..eyeBlinkElapsedSeconds = 11
      ..postureElapsedSeconds = 22
      ..hydrationElapsedSeconds = 33
      ..stretchElapsedSeconds = 44
      ..standUpElapsedSeconds = 55;
    repo.save(
      state,
      shortBreakIntervalMinutes: 20,
      shortBreakDurationSeconds: 20,
      preBreakWarningSeconds: 10,
      longBreakIntervalMinutes: 60,
      longBreakDurationMinutes: 5,
      pauseTimerAfterMinutes: 5,
      resetTimerAfterMinutes: 15,
    );

    final restored = TimerStateData();
    repo.restore(
      restored,
      defaultShortBreakIntervalMinutes: 20,
      defaultShortBreakDurationSeconds: 20,
      defaultPreBreakWarningSeconds: 10,
      defaultLongBreakIntervalMinutes: 60,
      defaultLongBreakDurationMinutes: 5,
      defaultPauseTimerAfterMinutes: 5,
      defaultResetTimerAfterMinutes: 15,
      onSettingsRestored: (a, b, c, d, e, f, g) {},
    );
    expect(restored.eyeBlinkElapsedSeconds, 11);
    expect(restored.postureElapsedSeconds, 22);
    expect(restored.hydrationElapsedSeconds, 33);
    expect(restored.stretchElapsedSeconds, 44);
    expect(restored.standUpElapsedSeconds, 55);
  });
}
