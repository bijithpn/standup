import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/services/calendar_event_service.dart';
import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/core/services/calendar_repository.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/core/services/timer_context_manager.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class FakeStorageService implements StorageService {
  @override
  bool get isReady => true;
  @override
  bool get hasFailed => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSettingsRepository extends SettingsRepository {
  final SettingsModel _settings;
  FakeSettingsRepository(this._settings) : super(storage: FakeStorageService());

  @override
  SettingsModel get currentSettings => _settings;
}

/// A CalendarService whose event list is fully test-controlled, bypassing
/// the native EventKit bridge entirely.
class FakeCalendarService extends CalendarService {
  List<CalendarEvent> events = [];

  FakeCalendarService()
    : super(
        permissionService: CalendarPermissionService(),
        eventService: CalendarEventService(CalendarRepository()),
      );

  @override
  Future<List<CalendarEvent>> getEvents(
    DateTime start,
    DateTime end, {
    List<String>? calendarIds,
  }) async => events;
}

void main() {
  late FakeCalendarService calendarService;
  late FakeSettingsRepository settingsRepository;
  late TimerContextManager contextManager;

  setUp(() {
    calendarService = FakeCalendarService();
    settingsRepository = FakeSettingsRepository(
      const SettingsModel(calendarEnabled: true, shortBreakDurationSeconds: 20),
    );
    contextManager = TimerContextManager(
      settingsRepository: settingsRepository,
      calendarService: calendarService,
    );
  });

  test('returns null when calendar is disabled', () async {
    settingsRepository = FakeSettingsRepository(
      const SettingsModel(calendarEnabled: false),
    );
    contextManager = TimerContextManager(
      settingsRepository: settingsRepository,
      calendarService: calendarService,
    );

    final result = await contextManager.minutesUntilNextFreeGap();
    expect(result, isNull);
  });

  test('returns null when there is no calendar service', () async {
    contextManager = TimerContextManager(
      settingsRepository: settingsRepository,
    );

    final result = await contextManager.minutesUntilNextFreeGap();
    expect(result, isNull);
  });

  test('returns null when now is already clear', () async {
    final now = DateTime(2026, 1, 1, 10, 0);
    calendarService.events = [];

    await withClock(Clock.fixed(now), () async {
      final result = await contextManager.minutesUntilNextFreeGap();
      expect(result, isNull);
    });
  });

  test('returns minutes to wait when a meeting is happening right now', () async {
    final now = DateTime(2026, 1, 1, 10, 0);
    calendarService.events = [
      CalendarEvent(
        title: 'Standup',
        start: now.subtract(const Duration(minutes: 5)),
        end: now.add(const Duration(minutes: 10)),
      ),
    ];

    await withClock(Clock.fixed(now), () async {
      final result = await contextManager.minutesUntilNextFreeGap();
      expect(result, equals(10));
    });
  });

  test('skips a short gap that is smaller than the break duration', () async {
    final now = DateTime(2026, 1, 1, 10, 0);
    settingsRepository = FakeSettingsRepository(
      const SettingsModel(
        calendarEnabled: true,
        shortBreakDurationSeconds: 5 * 60, // needs a 5-minute gap
      ),
    );
    contextManager = TimerContextManager(
      settingsRepository: settingsRepository,
      calendarService: calendarService,
    );
    calendarService.events = [
      // Meeting A starts too soon to fit a 5-minute break before it, and
      // meeting B follows with only a 2-minute gap after A — also too short.
      CalendarEvent(
        title: 'A',
        start: now.add(const Duration(minutes: 2)),
        end: now.add(const Duration(minutes: 30)),
      ),
      CalendarEvent(
        title: 'B',
        start: now.add(const Duration(minutes: 32)),
        end: now.add(const Duration(minutes: 60)),
      ),
    ];

    await withClock(Clock.fixed(now), () async {
      final result = await contextManager.minutesUntilNextFreeGap();
      // The first real gap big enough is after meeting B ends.
      expect(result, equals(60));
    });
  });

  test('finds the first sufficiently large gap between meetings', () async {
    final now = DateTime(2026, 1, 1, 10, 0);
    calendarService.events = [
      // Already in a meeting right now — too soon to fit even a 1-minute gap.
      CalendarEvent(
        title: 'A',
        start: now.subtract(const Duration(minutes: 5)),
        end: now.add(const Duration(minutes: 30)),
      ),
      // 20-minute gap here, plenty for a 20-second break.
      CalendarEvent(
        title: 'B',
        start: now.add(const Duration(minutes: 50)),
        end: now.add(const Duration(minutes: 80)),
      ),
    ];

    await withClock(Clock.fixed(now), () async {
      final result = await contextManager.minutesUntilNextFreeGap();
      expect(result, equals(30));
    });
  });

  test('ignores all-day events entirely', () async {
    final now = DateTime(2026, 1, 1, 10, 0);
    calendarService.events = [
      CalendarEvent(
        title: 'Company Holiday',
        start: now.subtract(const Duration(hours: 1)),
        end: now.add(const Duration(hours: 8)),
        isAllDay: true,
      ),
    ];

    await withClock(Clock.fixed(now), () async {
      final result = await contextManager.minutesUntilNextFreeGap();
      expect(result, isNull);
    });
  });
}
