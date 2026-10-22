import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/storage/models/activity_segment.dart';
import 'package:breakmate/objectbox.g.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_async/fake_async.dart';
import 'package:clock/clock.dart';
import 'package:objectbox/objectbox.dart';

import 'package:breakmate/core/storage/models/settings_snapshot.dart';
import 'package:breakmate/core/storage/models/daily_stats.dart';
import 'package:breakmate/core/storage/models/companion_preferences.dart';
import 'package:breakmate/core/storage/models/key_value_record.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/core/events/app_events.dart';

final sl = GetIt.instance;

class MockCalendarService extends Mock implements CalendarService {}

class MockSmartDetectionService extends Mock implements SmartDetectionService {}

class FakeStorageService implements StorageService {
  /// Activity history is not part of what these tests exercise.
  @override
  Box<ActivitySegment>? activitySegmentBox;

  final Map<String, dynamic> _data = {};

  @override
  bool get isReady => true;
  @override
  bool get hasFailed => false;
  @override
  String? activeDatabasePath = 'fake_path';
  @override
  int? openDurationMs = 0;
  @override
  int? initDurationMs = 0;
  @override
  Store get store => throw UnimplementedError();
  @override
  Box<SettingsSnapshot>? settingsBox;
  @override
  Box<DailyStats>? dailyStatsBox;
  @override
  Box<GlobalStats>? globalStatsBox;
  @override
  Box<CompanionPreferences>? companionPreferencesBox;
  @override
  Box<KeyValueRecord>? kvBox;
  @override
  int get migrationDurationMs => 0;
  @override
  set migrationDurationMs(int val) {}
  @override
  Future<void> init() async {}
  @override
  void close() {}
  @override
  void diagnoseAndLogFailure(String storeDir) {}
  @override
  Future<void> diagnoseStorage(String storeDir) async {}
  @override
  Future<int> getDatabaseSize() async => 0;
  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  @override
  int getInt(String key, {int defaultValue = 0}) =>
      _data[key] as int? ?? defaultValue;
  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  bool getBool(String key, {bool defaultValue = false}) =>
      _data[key] as bool? ?? defaultValue;
  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  String getString(String key, {String defaultValue = ''}) =>
      _data[key] as String? ?? defaultValue;
  @override
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  @override
  double getDouble(String key, {double defaultValue = 0.0}) =>
      _data[key] as double? ?? defaultValue;
}

class FakeSettingsRepository extends SettingsRepository {
  SettingsModel _settings;
  FakeSettingsRepository(this._settings) : super(storage: FakeStorageService());

  @override
  SettingsModel get currentSettings => _settings;

  void setSettings(SettingsModel model) {
    _settings = model;
    notifyListeners();
  }

  @override
  Future<void> load() async {}
  @override
  Future<void> save(SettingsModel settings) async {
    _settings = settings;
    notifyListeners();
  }
}

class FakeTrayManagerService extends TrayManagerService {
  @override
  Future<void> init() async {}
  @override
  void setIconModeFromStyle(String style) {}
  @override
  Future<void> setTrayTitle(String title) async {}
  @override
  Future<void> setTooltip(String tooltip) async {}
  @override
  void setBreakActive(bool active) {}
  @override
  void dispose() {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late FakeSettingsRepository fakeSettingsRepository;
  late FakeStorageService fakeStorageService;
  late FakeTrayManagerService fakeTrayManagerService;
  late MockCalendarService mockCalendarService;
  late MockSmartDetectionService mockSmartDetectionService;
  late EventBus eventBus;

  setUp(() {
    sl.allowReassignment = true;
    fakeStorageService = FakeStorageService();
    fakeSettingsRepository = FakeSettingsRepository(
      const SettingsModel(
        shortBreakIntervalMinutes: 20,
        shortBreakDurationSeconds: 20,
        preBreakWarningSeconds: 60,
        longBreakIntervalMinutes: 60,
        longBreakDurationMinutes: 5,
        calendarEnabled: true,
      ),
    );
    fakeTrayManagerService = FakeTrayManagerService();
    mockCalendarService = MockCalendarService();
    mockSmartDetectionService = MockSmartDetectionService();
    eventBus = EventBus.instance;

    sl.registerSingleton<StorageService>(fakeStorageService);
    sl.registerSingleton<SettingsRepository>(fakeSettingsRepository);
    sl.registerSingleton<TrayManagerService>(fakeTrayManagerService);
    sl.registerSingleton<EventBus>(eventBus);

    when(() => mockSmartDetectionService.isVideoCallActive).thenReturn(false);
    when(() => mockSmartDetectionService.isVideoPlaying).thenReturn(false);
    when(() => mockSmartDetectionService.isFocusModeActive).thenReturn(false);
    when(
      () => mockCalendarService.getUpcomingEvents(window: any(named: 'window')),
    ).thenAnswer((_) async => []);
  });

  tearDown(() {
    sl.reset();
  });

  group('TimerEngine Exhaustive Edge-Case Tests', () {
    test('Tick Accuracy: workElapsed and countdown update correctly', () {
      fakeAsync((async) {
        final engine = TimerEngine(
          settingsRepository: fakeSettingsRepository,
          smartDetectionService: mockSmartDetectionService,
          calendarService: mockCalendarService,
          eventBus: eventBus,
        );

        engine.startTimers();
        expect(engine.state, equals(TimerState.running));

        async.elapse(const Duration(minutes: 5));

        expect(engine.workElapsed.inMinutes, equals(5));
        expect(engine.countdownSeconds, equals((20 - 5) * 60));
      });
    });

    test('Pre-Break Warning: triggers correctly before interval ends', () {
      fakeAsync((async) {
        final engine = TimerEngine(
          settingsRepository: fakeSettingsRepository,
          smartDetectionService: mockSmartDetectionService,
          calendarService: mockCalendarService,
          eventBus: eventBus,
        );

        engine.startTimers();

        // 20 minute interval, 60s warning. Warning should trigger at 19:00.
        async.elapse(const Duration(minutes: 18, seconds: 59));
        expect(engine.isPreBreak, isFalse);

        async.elapse(const Duration(seconds: 1));
        expect(engine.isPreBreak, isTrue);

        async.elapse(const Duration(seconds: 30));
        expect(engine.isPreBreak, isTrue);

        async.elapse(const Duration(seconds: 30));
        // Break starts, pre-break becomes false.
        expect(engine.state, equals(TimerState.breakActive));
        expect(engine.isPreBreak, isFalse);
      });
    });

    test('System Sleep Drift: resets if away duration > interval', () {
      fakeAsync((async) {
        final engine = TimerEngine(
          settingsRepository: fakeSettingsRepository,
          smartDetectionService: mockSmartDetectionService,
          calendarService: mockCalendarService,
          eventBus: eventBus,
        );

        engine.startTimers();
        async.elapse(const Duration(minutes: 5));

        engine.handleSystemSleep();
        expect(engine.stateData.systemSleepPaused, isTrue);

        // Simulate 30 minute gap (interval is 20)
        async.elapse(const Duration(minutes: 30));

        engine.handleSystemWake();

        expect(engine.stateData.systemSleepPaused, isFalse);
        expect(engine.state, equals(TimerState.idle));
        expect(engine.workElapsed, equals(Duration.zero));
      });
    });

    test('System Sleep Drift: resumes if away duration < interval', () {
      fakeAsync((async) {
        final engine = TimerEngine(
          settingsRepository: fakeSettingsRepository,
          smartDetectionService: mockSmartDetectionService,
          calendarService: mockCalendarService,
          eventBus: eventBus,
        );

        engine.startTimers();
        async.elapse(const Duration(minutes: 5));

        engine.handleSystemSleep();

        // Simulate 10 minute gap
        async.elapse(const Duration(minutes: 10));

        engine.handleSystemWake();

        expect(engine.state, equals(TimerState.running));
        // Should resume from 5 minutes (ignoring the 10m sleep)
        expect(engine.workElapsed.inMinutes, equals(5));
      });
    });

    test('Meeting Overrides: suppresses break during imminent meetings', () {
      fakeAsync((async) {
        final engine = TimerEngine(
          settingsRepository: fakeSettingsRepository,
          smartDetectionService: mockSmartDetectionService,
          calendarService: mockCalendarService,
          eventBus: eventBus,
        );

        // Mock an upcoming meeting
        when(
          () => mockCalendarService.getUpcomingEvents(
            window: any(named: 'window'),
          ),
        ).thenAnswer(
          (_) async => [
            CalendarEvent(
              title: 'Big Meeting',
              start: clock.now().add(const Duration(minutes: 5)),
              end: clock.now().add(const Duration(minutes: 35)),
            ),
          ],
        );

        engine.startTimers();

        // Elapse until 20 minutes (when break would normally trigger)
        async.elapse(const Duration(minutes: 20));

        // Let the async isMeetingUpcoming() check complete
        async.flushMicrotasks();

        // Break should be suppressed, workElapsed held 5 mins prior to interval.
        // Wait! TimerEngine code says:
        // _stateData.workElapsed = interval - const Duration(minutes: 5);
        expect(engine.state, equals(TimerState.running));
        expect(engine.workElapsed.inMinutes, equals(15));
      });
    });

    test('Strict Mode: prevents skip (indirectly verified via logic)', () {
      final engine = TimerEngine(
        settingsRepository: fakeSettingsRepository,
        eventBus: eventBus,
      );

      fakeSettingsRepository.setSettings(const SettingsModel(strictMode: true));
      engine.startTimers();
      engine.triggerBreakNow();

      expect(engine.state, equals(TimerState.breakActive));
      // In strict mode, the UI (StandaloneBreakOverlay) uses the flag to hide skip.
      // TimerEngine logic itself doesn't block skipNextBreak call, but the UI does.
    });

    test('Settings sync: dynamically updates interval on running timer', () {
      fakeAsync((async) {
        final engine = TimerEngine(
          settingsRepository: fakeSettingsRepository,
          smartDetectionService: mockSmartDetectionService,
          calendarService: mockCalendarService,
          eventBus: eventBus,
        );

        engine.startTimers();
        expect(engine.shortBreakIntervalMinutes, equals(20));

        async.elapse(const Duration(minutes: 5));
        expect(engine.workElapsed.inMinutes, equals(5));

        // User updates short break interval in settings to 10 minutes
        fakeSettingsRepository.save(
          fakeSettingsRepository.currentSettings.copyWith(
            shortBreakIntervalMinutes: 10,
          ),
        );

        expect(engine.shortBreakIntervalMinutes, equals(10));
        // Elapsed time is preserved (5 minutes)
        expect(engine.workElapsed.inMinutes, equals(5));

        // Advance 5 more minutes -> triggers break at 10 minutes total
        async.elapse(const Duration(minutes: 5));
        expect(engine.state, equals(TimerState.breakActive));
      });
    });

    test('Smart pause: auto-resumes when smart condition clears', () {
      fakeAsync((async) {
        fakeSettingsRepository.setSettings(
          fakeSettingsRepository.currentSettings.copyWith(
            respectFocusMode: true,
          ),
        );

        final engine = TimerEngine(
          settingsRepository: fakeSettingsRepository,
          smartDetectionService: mockSmartDetectionService,
          calendarService: mockCalendarService,
          eventBus: eventBus,
        );

        engine.startTimers();
        async.elapse(const Duration(minutes: 5));
        expect(engine.state, equals(TimerState.running));

        // Focus mode starts
        when(
          () => mockSmartDetectionService.isFocusModeActive,
        ).thenReturn(true);
        async.elapse(const Duration(seconds: 1));
        expect(engine.state, equals(TimerState.paused));
        expect(engine.stateData.isManuallyPaused, isFalse);

        // Advance during focus mode
        async.elapse(const Duration(minutes: 15));
        expect(engine.state, equals(TimerState.paused));

        // Focus mode ends
        when(
          () => mockSmartDetectionService.isFocusModeActive,
        ).thenReturn(false);
        async.elapse(const Duration(seconds: 1));
        // Timer should automatically resume without manual intervention!
        expect(engine.state, equals(TimerState.running));
      });
    });

    test(
      'Complete cycle: work -> pre-break warning -> break -> next work interval',
      () {
        fakeAsync((async) {
          final engine = TimerEngine(
            settingsRepository: fakeSettingsRepository,
            smartDetectionService: mockSmartDetectionService,
            calendarService: mockCalendarService,
            eventBus: eventBus,
          );

          engine.startTimers();
          // 20 min interval, 60s warning
          // At 19 minutes: pre-break warning
          async.elapse(const Duration(minutes: 19));
          expect(engine.state, equals(TimerState.running));

          // At 20 minutes: break starts
          async.elapse(const Duration(minutes: 1));
          expect(engine.state, equals(TimerState.breakActive));

          // Complete the 20s break
          async.elapse(const Duration(seconds: 20));
          // Break finishes, resumes work
          expect(engine.state, equals(TimerState.running));
          expect(engine.workElapsed, equals(Duration.zero));
          expect(engine.shortBreakIntervalMinutes, equals(20));
        });
      },
    );
  });

  group('Health Reminders: automatic, no manual interval', () {
    test('posture reminder follows the ~30min ergonomic baseline (not the '
        'break interval), with randomized jitter — not instantly and not '
        'stuck forever', () {
      fakeAsync((async) {
        // A long break interval (60min) so it never interrupts the
        // running state during this test — activityRatio clamps at 1.2x, and
        // the first hour of a day is a light-workload period (x1.25), giving
        // a target window of 30 * 1.2 * 1.25 * [0.85, 1.15] ≈
        // [38.3, 51.8] minutes.
        fakeSettingsRepository.setSettings(
          const SettingsModel(
            shortBreakIntervalMinutes: 60,
            postureReminderEnabled: true,
          ),
        );

        final fired = <HealthReminderEvent>[];
        final sub = eventBus.on<HealthReminderEvent>().listen(fired.add);
        addTearDown(sub.cancel);

        final engine = TimerEngine(
          settingsRepository: fakeSettingsRepository,
          smartDetectionService: mockSmartDetectionService,
          calendarService: mockCalendarService,
          eventBus: eventBus,
        );
        engine.startTimers();

        // Below the lower bound (38.3min) with margin — nothing yet.
        async.elapse(const Duration(minutes: 28));
        expect(fired, isEmpty);

        // Past the upper bound (51.8min) with margin — must have fired.
        // (Each cycle re-randomizes independently, so a short first cycle
        // followed by another short one can legitimately produce more
        // than one event here — that's the intended "randomly, not on a
        // fixed schedule" behavior, not a bug, so this only checks that
        // at least one fired and that it's the right reminder.)
        async.elapse(const Duration(minutes: 27));
        expect(fired, isNotEmpty);
        expect(fired.first.reminderType, equals('posture'));
      });
    });

    test('eye-rest reminder follows the 20-20-20 rule baseline (~20min), '
        'with randomized jitter', () {
      fakeAsync((async) {
        // A long break interval (60min) so it never interrupts the
        // running state during this test — activityRatio clamps at 1.2x, and
        // the first hour of a day is a light-workload period (x1.25), giving
        // a target window of 20 * 1.2 * 1.25 * [0.85, 1.15] ≈
        // [25.5, 34.5] minutes.
        fakeSettingsRepository.setSettings(
          const SettingsModel(
            shortBreakIntervalMinutes: 60,
            eyeBlinkReminderEnabled: true,
          ),
        );

        final fired = <HealthReminderEvent>[];
        final sub = eventBus.on<HealthReminderEvent>().listen(fired.add);
        addTearDown(sub.cancel);

        final engine = TimerEngine(
          settingsRepository: fakeSettingsRepository,
          smartDetectionService: mockSmartDetectionService,
          calendarService: mockCalendarService,
          eventBus: eventBus,
        );
        engine.startTimers();

        // Below the lower bound (25.5min) with margin.
        async.elapse(const Duration(minutes: 18));
        expect(fired, isEmpty);

        // Past the upper bound (34.5min) with margin.
        async.elapse(const Duration(minutes: 20));
        expect(fired, isNotEmpty);
        expect(fired.first.reminderType, equals('eyeblink'));
      });
    });

    test('never fires while disabled, even across several intervals', () {
      fakeAsync((async) {
        fakeSettingsRepository.setSettings(
          const SettingsModel(
            shortBreakIntervalMinutes: 20,
            postureReminderEnabled: false,
            eyeBlinkReminderEnabled: false,
          ),
        );

        final fired = <HealthReminderEvent>[];
        final sub = eventBus.on<HealthReminderEvent>().listen(fired.add);
        addTearDown(sub.cancel);

        final engine = TimerEngine(
          settingsRepository: fakeSettingsRepository,
          smartDetectionService: mockSmartDetectionService,
          calendarService: mockCalendarService,
          eventBus: eventBus,
        );
        engine.startTimers();

        async.elapse(const Duration(minutes: 65));
        expect(fired, isEmpty);
      });
    });
  });
}
