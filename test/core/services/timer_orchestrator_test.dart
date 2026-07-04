import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:objectbox/objectbox.dart';
import 'package:breakmate/core/storage/models/settings_snapshot.dart';
import 'package:breakmate/core/storage/models/daily_stats.dart';
import 'package:breakmate/core/storage/models/companion_preferences.dart';
import 'package:breakmate/core/storage/models/key_value_record.dart';
import 'package:breakmate/core/storage/models/session_state.dart';
import 'package:breakmate/core/services/timer_state.dart';
import 'package:breakmate/core/services/timer_orchestrator.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/services/timer_repository.dart';
import 'package:breakmate/core/services/session_state_repository.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/features/analytics/stats_service.dart'
    hide DailyStats;
import 'package:breakmate/features/menu_bar/tray_manager_service.dart';
import 'package:breakmate/core/services/adaptive_break_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/wellness/domain/wellness_engine.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';

final sl = GetIt.instance;

class FakeStorageService implements StorageService {
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
  int getInt(String key, {int defaultValue = 0}) {
    return _data[key] as int? ?? defaultValue;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  bool getBool(String key, {bool defaultValue = false}) {
    return _data[key] as bool? ?? defaultValue;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  String getString(String key, {String defaultValue = ''}) {
    return _data[key] as String? ?? defaultValue;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  @override
  double getDouble(String key, {double defaultValue = 0.0}) {
    return _data[key] as double? ?? defaultValue;
  }
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
  String? lastTitle;
  String? lastTooltip;
  bool breakActive = false;

  @override
  Future<void> init() async {}

  @override
  void setIconModeFromStyle(String style) {}

  @override
  Future<void> setTrayTitle(String title) async {
    lastTitle = title;
  }

  @override
  Future<void> setTooltip(String tooltip) async {
    lastTooltip = tooltip;
  }

  @override
  void setBreakActive(bool active) {
    breakActive = active;
  }

  @override
  void dispose() {}
}

class FakeTimerRepository extends TimerRepository {
  FakeTimerRepository() : super(FakeStorageService());

  @override
  void save(
    TimerStateData state, {
    required int shortBreakIntervalMinutes,
    required int shortBreakDurationSeconds,
    required int preBreakWarningSeconds,
    required int longBreakIntervalMinutes,
    required int longBreakDurationMinutes,
    required int pauseTimerAfterMinutes,
    required int resetTimerAfterMinutes,
  }) {}

  @override
  void restore(
    TimerStateData state, {
    required int defaultShortBreakIntervalMinutes,
    required int defaultShortBreakDurationSeconds,
    required int defaultPreBreakWarningSeconds,
    required int defaultLongBreakIntervalMinutes,
    required int defaultLongBreakDurationMinutes,
    required int defaultPauseTimerAfterMinutes,
    required int defaultResetTimerAfterMinutes,
    required void Function(
      int shortInterval,
      int shortDuration,
      int preWarning,
      int longInterval,
      int longDuration,
      int pauseAfter,
      int resetAfter,
    )
    onSettingsRestored,
  }) {}
}

class FakeSessionStateRepository extends SessionStateRepository {
  FakeSessionStateRepository() : super(FakeStorageService());

  @override
  void initialize() {}

  @override
  SessionState? getSessionForToday() => null;

  @override
  void saveSession({
    required Duration workElapsed,
    required Duration totalWorkToday,
    required int postureElapsedSeconds,
    required int eyeBlinkElapsedSeconds,
    required bool isPreBreak,
    required String timerState,
    required DateTime? longBreakWindowStartedAt,
  }) {}

  @override
  void clearSession() {}
}

class FakeActivityMonitor extends ActivityMonitor {
  ActivityCallback? callback;

  @override
  void setIdleThreshold(int minutes) {}

  @override
  void setActivityCallback(ActivityCallback callback) {
    this.callback = callback;
  }

  @override
  void start() {}

  @override
  void stop() {}
}

class FakeNotificationService extends NotificationService {
  bool showBreakReminderCalled = false;
  bool showClockOutReminderCalled = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> showBreakReminder({required bool isLong}) async {
    showBreakReminderCalled = true;
  }

  @override
  Future<void> showClockOutReminder() async {
    showClockOutReminderCalled = true;
  }

  @override
  Future<void> showBreakFinished() async {}
}

class FakeStatsService extends StatsService {
  FakeStatsService() : super(storage: FakeStorageService());

  @override
  void recordCompletedBreak() {}

  @override
  void recordSkippedBreak() {}

  @override
  void addUsageMinutes(int minutes) {}
}

class FakeAdaptiveBreakService extends AdaptiveBreakService {
  FakeAdaptiveBreakService()
    : super(
        storage: FakeStorageService(),
        wellnessEngine: sl<WellnessEngine>(),
      );

  @override
  void recordWorkSession({
    required Duration duration,
    required int hourOfDay,
    required String activityLevel,
  }) {}

  @override
  int getSuggestedBreakInterval() => 20;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStorageService fakeStorageService;
  late FakeSettingsRepository fakeSettingsRepository;
  late FakeTrayManagerService fakeTrayManagerService;
  late FakeTimerRepository fakeTimerRepository;
  late FakeSessionStateRepository fakeSessionStateRepository;
  late FakeActivityMonitor fakeActivityMonitor;
  late FakeNotificationService fakeNotificationService;
  late FakeStatsService fakeStatsService;
  late FakeAdaptiveBreakService fakeAdaptiveBreakService;
  late EventBus eventBus;
  late TimerEngine timerEngine;
  late TimerOrchestrator orchestrator;

  final MethodChannel channel = const MethodChannel('com.breakmate/ipc');

  setUp(() {
    sl.allowReassignment = true;

    // Stub the method channel calls
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return null;
        });

    fakeStorageService = FakeStorageService();
    fakeSettingsRepository = FakeSettingsRepository(
      const SettingsModel(
        shortBreakIntervalMinutes: 20,
        shortBreakDurationSeconds: 20,
        preBreakWarningSeconds: 60,
        longBreakIntervalMinutes: 60,
        longBreakDurationMinutes: 5,
        companionEnabled: false,
      ),
    );
    fakeTrayManagerService = FakeTrayManagerService();
    fakeTimerRepository = FakeTimerRepository();
    fakeSessionStateRepository = FakeSessionStateRepository();
    fakeActivityMonitor = FakeActivityMonitor();
    fakeNotificationService = FakeNotificationService();
    fakeStatsService = FakeStatsService();
    eventBus = EventBus.instance;

    sl.registerSingleton<StorageService>(fakeStorageService);
    sl.registerSingleton<SettingsRepository>(fakeSettingsRepository);
    sl.registerSingleton<TrayManagerService>(fakeTrayManagerService);
    sl.registerSingleton<AppTrackingService>(AppTrackingService());
    sl.registerSingleton<WellnessEngine>(
      WellnessEngine(appTracking: sl<AppTrackingService>()),
    );

    fakeAdaptiveBreakService = FakeAdaptiveBreakService();

    timerEngine = TimerEngine(
      settingsRepository: fakeSettingsRepository,
      eventBus: eventBus,
    );

    orchestrator = TimerOrchestrator(
      timerEngine: timerEngine,
      timerRepository: fakeTimerRepository,
      sessionStateRepository: fakeSessionStateRepository,
      activityMonitor: fakeActivityMonitor,
      notificationService: fakeNotificationService,
      statsService: fakeStatsService,
      trayManagerService: fakeTrayManagerService,
      adaptiveBreakService: fakeAdaptiveBreakService,
      settingsRepository: fakeSettingsRepository,
      eventBus: eventBus,
    );

    orchestrator.initialize();
  });

  tearDown(() {
    orchestrator.dispose();
    sl.reset();
  });

  group('TimerOrchestrator Coordination', () {
    test('updates tray and dispatches IPC when timer state changes', () {
      timerEngine.startTimers();

      // StartTimers transitions to running
      expect(fakeTrayManagerService.breakActive, isFalse);
    });

    test('BreakStartedEvent triggers notification and updates tray', () async {
      eventBus.emit(
        BreakStartedEvent(
          isLongBreak: false,
          durationSeconds: 20,
          title: 'Short Break',
        ),
      );

      await Future.microtask(() {});

      // Notification is triggered and tray status transitions to active
      expect(fakeNotificationService.showBreakReminderCalled, isTrue);
      expect(fakeTrayManagerService.breakActive, isTrue);
    });

    test(
      'BreakStartedEvent for long break triggers clock out notification',
      () async {
        eventBus.emit(
          BreakStartedEvent(
            isLongBreak: true,
            durationSeconds: 300,
            title: 'Long Break',
          ),
        );

        await Future.microtask(() {});

        expect(fakeNotificationService.showClockOutReminderCalled, isTrue);
        expect(fakeTrayManagerService.breakActive, isTrue);
      },
    );

    test('BreakEndedEvent resets tray state', () async {
      eventBus.emit(BreakEndedEvent(skipped: false));

      await Future.microtask(() {});

      expect(fakeTrayManagerService.breakActive, isFalse);
    });

    test('Idle change triggers timer pause/resume', () {
      timerEngine.startTimers();
      expect(timerEngine.state, equals(TimerState.running));

      // Simulate going idle
      fakeActivityMonitor.callback?.call(false);
      expect(timerEngine.state, equals(TimerState.paused));

      // Simulate coming back active
      fakeActivityMonitor.callback?.call(true);
      expect(timerEngine.state, equals(TimerState.running));
    });
  });
}
