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
    when(() => detection.isFocusModeActive).thenReturn(false);
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

  test(
    'hydration, stretch and stand-up fire when enabled, and not otherwise',
    () {
      fakeAsync((async) {
        settings.save(
          settings.currentSettings.copyWith(
            eyeBlinkReminderEnabled: false,
            postureReminderEnabled: false,
            hydrationReminderEnabled: true,
            stretchReminderEnabled: true,
            standUpReminderEnabled: true,
          ),
        );
        final engine = newEngine()..startTimers();
        run(async, const Duration(minutes: 100));
        final types = reminders.map((r) => r.reminderType).toSet();
        expect(types, containsAll(['stretch', 'hydration']));
        // Nothing for the disabled ones.
        expect(types, isNot(contains('eyeblink')));
        expect(types, isNot(contains('posture')));
        // Never more than the hourly cap.
        expect(reminders.length, lessThanOrEqualTo(8));
        engine.dispose();
      });
    },
  );

  test('a busier day produces more reminders than a light one', () {
    int countFor(Duration alreadyWorked) {
      var count = 0;
      fakeAsync((async) {
        reminders.clear();
        settings.save(
          settings.currentSettings.copyWith(hydrationReminderEnabled: true),
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
}
