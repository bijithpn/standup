import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/services/daily_reset_service.dart';
import 'package:breakmate/core/services/session_state_repository.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

import 'timer_engine_drift_test.dart'
    show FakeStorageService, MockCalendarService, MockSmartDetectionService;

class _FakeSessions extends SessionStateRepository {
  int cleared = 0;
  _FakeSessions(super.storage);
  @override
  void clearSession() => cleared++;
}

/// `fakeAsync` starts at the real current time, so pin it to a known local
/// instant with `withClock`.
void main() {
  final sl = GetIt.instance;
  late FakeStorageService storage;
  late SettingsRepository settingsRepo;
  late MockCalendarService calendar;
  late MockSmartDetectionService detection;

  setUp(() {
    sl.reset();
    storage = FakeStorageService();
    settingsRepo = SettingsRepository(storage: storage);
    calendar = MockCalendarService();
    detection = MockSmartDetectionService();
    sl.registerSingleton<StorageService>(storage);
    sl.registerSingleton<SettingsRepository>(settingsRepo);
    sl.registerSingleton<CalendarService>(calendar);
    sl.registerSingleton<SmartDetectionService>(detection);
    sl.registerSingleton<EventBus>(EventBus.instance);
    when(() => calendar.isMeetingActive()).thenAnswer((_) async => false);
    when(() => detection.isVideoCallActive).thenReturn(false);
    when(() => detection.isVideoPlaying).thenReturn(false);
  });

  /// Runs [body] with a controllable local clock starting at [start].
  void scenario(
    DateTime start,
    void Function(
      FakeAsync async,
      TimerEngine engine,
      DailyResetService service,
      _FakeSessions sessions,
      void Function(Duration) advance,
    )
    body,
  ) {
    fakeAsync((async) {
      var now = start;
      withClock(Clock(() => now), () {
        final engine = TimerEngine(
          settingsRepository: settingsRepo,
          smartDetectionService: detection,
          calendarService: calendar,
          eventBus: EventBus.instance,
        );
        final sessions = _FakeSessions(storage);
        final stats = StatsService(storage: storage);
        final service = DailyResetService(
          storage: storage,
          timerEngine: engine,
          statsService: stats,
          sessionStateRepository: sessions,
        );
        void advance(Duration d) {
          now = now.add(d);
          async.elapse(d);
        }

        body(async, engine, service, sessions, advance);
        service.dispose();
        engine.dispose();
      });
    });
  }

  final lateEvening = DateTime(2026, 3, 10, 23, 50);

  test('first launch only stamps the day; nothing is reset', () {
    scenario(lateEvening, (async, engine, service, sessions, advance) {
      engine.startTimers();
      engine.stateData.totalWorkToday = const Duration(hours: 3);
      service.start();
      expect(storage.getString(DailyResetService.storageKey), '2026-03-10');
      expect(engine.totalWorkToday, const Duration(hours: 3));
      expect(sessions.cleared, 0);
    });
  });

  test('midnight timer resets the day once and re-arms for the next', () {
    scenario(lateEvening, (async, engine, service, sessions, advance) {
      engine.startTimers();
      service.start();
      engine.stateData.totalWorkToday = const Duration(hours: 5);
      engine.stateData.clockOutTriggered = true;

      advance(const Duration(minutes: 11));
      expect(storage.getString(DailyResetService.storageKey), '2026-03-11');
      expect(sessions.cleared, 1);
      expect(engine.totalWorkToday, Duration.zero);
      expect(engine.stateData.clockOutTriggered, isFalse);
      expect(engine.workElapsed, Duration.zero);
      expect(service.isMidnightTimerArmed, isTrue);

      // Repeated lifecycle events on the same day are no-ops.
      service.onSystemWake();
      service.reconcile();
      service.start();
      expect(sessions.cleared, 1);
    });
  });

  test('sleep through midnight: wake performs exactly one reset', () {
    scenario(lateEvening, (async, engine, service, sessions, advance) {
      engine.startTimers();
      service.start();
      engine.stateData.totalWorkToday = const Duration(hours: 2);

      engine.handleSystemSleep();
      advance(const Duration(hours: 8));
      engine.handleSystemWake();
      service.onSystemWake();
      service.onSystemWake();

      expect(sessions.cleared, 1);
      expect(engine.totalWorkToday, Duration.zero);
      expect(storage.getString(DailyResetService.storageKey), '2026-03-11');
    });
  });

  test('restart after midnight resets once from the persisted day', () {
    storage.setString(DailyResetService.storageKey, '2026-03-10');
    scenario(DateTime(2026, 3, 11, 9), (async, engine, service, sessions, _) {
      engine.stateData.totalWorkToday = const Duration(hours: 4);
      engine.stateData.clockOutTriggered = true;
      service.start();
      expect(sessions.cleared, 1);
      expect(engine.totalWorkToday, Duration.zero);
      expect(engine.stateData.clockOutTriggered, isFalse);
    });
  });

  test('a break crossing midnight is untouched; reset runs after it ends', () {
    scenario(DateTime(2026, 3, 10, 23, 59, 50), (
      async,
      engine,
      service,
      sessions,
      advance,
    ) {
      engine.startTimers();
      service.start();
      engine.stateData.totalWorkToday = const Duration(hours: 1);
      engine.triggerBreakNow();
      expect(engine.countdownSeconds, greaterThan(15));
      final deadline = engine.targetEndTime;

      advance(const Duration(seconds: 15)); // crosses midnight mid-break
      expect(engine.state, TimerState.breakActive);
      expect(service.hasPendingReset, isTrue);
      expect(sessions.cleared, 0);
      expect(engine.totalWorkToday, const Duration(hours: 1));
      expect(engine.targetEndTime, deadline);

      engine.finishBreak(skipped: false);
      async.flushMicrotasks();
      expect(service.hasPendingReset, isFalse);
      expect(sessions.cleared, 1);
      expect(engine.totalWorkToday, Duration.zero);
      expect(engine.state, TimerState.running);
    });
  });

  test('date moving backwards (timezone/clock change) never resets', () {
    storage.setString(DailyResetService.storageKey, '2026-03-12');
    scenario(DateTime(2026, 3, 11, 9), (async, engine, service, sessions, _) {
      engine.stateData.totalWorkToday = const Duration(hours: 1);
      service.start();
      expect(sessions.cleared, 0);
      expect(engine.totalWorkToday, const Duration(hours: 1));
      expect(storage.getString(DailyResetService.storageKey), '2026-03-12');
    });
  });

  test('month/year boundary arms the timer for the 1st', () {
    scenario(DateTime(2026, 12, 31, 23, 59, 30), (
      async,
      engine,
      service,
      sessions,
      advance,
    ) {
      engine.startTimers();
      service.start();
      advance(const Duration(seconds: 40));
      expect(storage.getString(DailyResetService.storageKey), '2027-01-01');
      expect(sessions.cleared, 1);
    });
  });

  test('start() twice does not duplicate listeners or resets', () {
    scenario(lateEvening, (async, engine, service, sessions, advance) {
      engine.startTimers();
      service.start();
      service.start();
      advance(const Duration(minutes: 11));
      expect(sessions.cleared, 1);
    });
  });
}
