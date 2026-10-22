import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

import 'timer_engine_drift_test.dart'
    show FakeStorageService, MockCalendarService, MockSmartDetectionService;

/// Break countdown must be derived from an absolute deadline so that system
/// sleep/wake (and lock/unlock) can never revive a stale counter.
void main() {
  final sl = GetIt.instance;
  late FakeStorageService storage;
  late SettingsRepository settingsRepo;
  late MockCalendarService calendar;
  late MockSmartDetectionService detection;
  late EventBus eventBus;
  late List<AppEvent> events;

  setUp(() {
    sl.reset();
    storage = FakeStorageService();
    settingsRepo = SettingsRepository(storage: storage);
    calendar = MockCalendarService();
    detection = MockSmartDetectionService();
    eventBus = EventBus.instance;
    sl.registerSingleton<StorageService>(storage);
    sl.registerSingleton<SettingsRepository>(settingsRepo);
    sl.registerSingleton<CalendarService>(calendar);
    sl.registerSingleton<SmartDetectionService>(detection);
    sl.registerSingleton<EventBus>(eventBus);
    when(() => calendar.isMeetingActive()).thenAnswer((_) async => false);
    when(() => detection.isVideoCallActive).thenReturn(false);
    when(() => detection.isVideoPlaying).thenReturn(false);
    when(() => detection.isFocusModeActive).thenReturn(false);
    events = [];
    eventBus.stream.listen(events.add);
  });

  TimerEngine newEngine() => TimerEngine(
    settingsRepository: settingsRepo,
    smartDetectionService: detection,
    calendarService: calendar,
    eventBus: eventBus,
  );

  int breakEnds() => events.whereType<BreakEndedEvent>().length;

  group('break countdown across sleep', () {
    test(
      'short sleep: remaining time reflects wall clock, not stale counter',
      () {
        fakeAsync((async) {
          final engine = newEngine()..startTimers();
          engine.triggerBreakNow();
          final total = engine.countdownSeconds;
          expect(engine.state, TimerState.breakActive);

          async.elapse(const Duration(seconds: 5));
          engine.handleSystemSleep();
          async.elapse(const Duration(seconds: 10));
          engine.handleSystemWake();

          expect(engine.state, TimerState.breakActive);
          expect(engine.countdownSeconds, total - 15);
          expect(engine.countdownNotifier.value, total - 15);
          expect(
            engine.targetEndTime!.difference(clock.now()).inSeconds,
            engine.countdownSeconds,
          );
          engine.dispose();
        });
      },
    );

    test('sleep longer than remaining: completes once, never restarts', () {
      fakeAsync((async) {
        final engine = newEngine()..startTimers();
        engine.triggerBreakNow();
        async.elapse(const Duration(seconds: 3));
        engine.handleSystemSleep();
        async.elapse(const Duration(minutes: 45));
        engine.handleSystemWake();
        async.flushMicrotasks();

        expect(engine.state, isNot(TimerState.breakActive));
        expect(engine.activeBreak, isNull);
        expect(breakEnds(), 1);
        expect(engine.targetEndTime, isNotNull); // new work deadline, not break

        // Repeated wake/unlock notifications must not duplicate anything.
        engine.handleSystemWake();
        engine.handleSystemWake();
        async.flushMicrotasks();
        expect(breakEnds(), 1);
        engine.dispose();
      });
    });

    test('repeated sleep/wake cycles keep one consistent deadline', () {
      fakeAsync((async) {
        final engine = newEngine()..startTimers();
        engine.triggerBreakNow();
        final deadline = engine.targetEndTime!;
        for (var i = 0; i < 3; i++) {
          engine.handleSystemSleep();
          async.elapse(const Duration(seconds: 2));
          engine.handleSystemWake();
        }
        expect(engine.targetEndTime, deadline);
        expect(breakEnds(), 0);
        engine.dispose();
      });
    });

    test('postpone moves the deadline, not a separate counter', () {
      fakeAsync((async) {
        final engine = newEngine()..startTimers();
        engine.triggerBreakNow();
        final before = engine.countdownSeconds;
        engine.postponeBreak();
        expect(engine.countdownSeconds, before + 120);
        engine.handleSystemSleep();
        async.elapse(const Duration(seconds: 10));
        engine.handleSystemWake();
        expect(engine.countdownSeconds, before + 110);
        engine.dispose();
      });
    });

    test('tick expiry completes the break exactly once', () {
      fakeAsync((async) {
        final engine = newEngine()..startTimers();
        engine.triggerBreakNow();
        async.elapse(Duration(seconds: engine.countdownSeconds + 5));
        async.flushMicrotasks();
        expect(engine.state, isNot(TimerState.breakActive));
        expect(breakEnds(), 1);
        engine.dispose();
      });
    });
  });

  group('pause across sleep', () {
    test('manually paused timer stays paused with remaining time intact', () {
      fakeAsync((async) {
        final engine = newEngine()..startTimers();
        async.elapse(const Duration(minutes: 2));
        engine.pauseTimers(isManual: true);
        final remaining = engine.countdownSeconds;

        engine.handleSystemSleep();
        async.elapse(const Duration(minutes: 5));
        engine.handleSystemWake();

        expect(engine.state, TimerState.paused);
        expect(engine.countdownSeconds, remaining);

        engine.resumeTimers();
        expect(engine.state, TimerState.running);
        expect(engine.countdownSeconds, remaining);
        engine.dispose();
      });
    });
  });
}
