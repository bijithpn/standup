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
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

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

  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  Future<bool> clear() async {
    _data.clear();
    return true;
  }
}

void main() {
  final sl = GetIt.instance;

  late SettingsRepository settingsRepo;
  late MockCalendarService mockCalendar;
  late MockSmartDetectionService mockDetection;
  late FakeStorageService fakeStorage;
  late EventBus eventBus;

  setUp(() {
    sl.reset();
    fakeStorage = FakeStorageService();
    settingsRepo = SettingsRepository(storage: fakeStorage);
    mockCalendar = MockCalendarService();
    mockDetection = MockSmartDetectionService();
    eventBus = EventBus.instance;

    sl.registerSingleton<StorageService>(fakeStorage);
    sl.registerSingleton<SettingsRepository>(settingsRepo);
    sl.registerSingleton<CalendarService>(mockCalendar);
    sl.registerSingleton<SmartDetectionService>(mockDetection);
    sl.registerSingleton<EventBus>(eventBus);

    when(() => mockCalendar.isMeetingActive()).thenAnswer((_) async => false);
    when(() => mockDetection.isVideoCallActive).thenReturn(false);
    when(() => mockDetection.isVideoPlaying).thenReturn(false);
  });

  group('TimerEngine OS Drift / Sleep Delta tests', () {
    test(
      'TimerEngine handles long system clock sleep drift by resetting to idle',
      () {
        fakeAsync((async) {
          final engine = TimerEngine(
            settingsRepository: settingsRepo,
            smartDetectionService: mockDetection,
            calendarService: mockCalendar,
            eventBus: eventBus,
          );

          engine.startTimers();
          expect(engine.state, equals(TimerState.running));

          async.elapse(const Duration(minutes: 5));
          expect(engine.workElapsed.inMinutes, equals(5));

          engine.handleSystemSleep();

          withClock(
            Clock.fixed(clock.now().add(const Duration(minutes: 30))),
            () {
              engine.handleSystemWake();
              expect(engine.state, equals(TimerState.idle));
              expect(engine.workElapsed, equals(Duration.zero));
            },
          );
        });
      },
    );

    test(
      'TimerEngine handles short system clock sleep drift by resuming to running',
      () {
        fakeAsync((async) {
          final engine = TimerEngine(
            settingsRepository: settingsRepo,
            smartDetectionService: mockDetection,
            calendarService: mockCalendar,
            eventBus: eventBus,
          );

          engine.startTimers();
          expect(engine.state, equals(TimerState.running));

          async.elapse(const Duration(minutes: 5));
          expect(engine.workElapsed.inMinutes, equals(5));

          engine.handleSystemSleep();

          withClock(
            Clock.fixed(clock.now().add(const Duration(minutes: 10))),
            () {
              engine.handleSystemWake();
              expect(engine.state, equals(TimerState.running));
              expect(engine.workElapsed.inMinutes, equals(5));
            },
          );
        });
      },
    );
  });
}
