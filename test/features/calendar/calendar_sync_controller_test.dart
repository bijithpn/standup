import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';
import 'package:breakmate/features/settings/settings_model.dart';

import '../../helpers/in_memory_settings_repository.dart';

class _FakePermissions extends CalendarPermissionService {
  CalendarPermissionStatus status = CalendarPermissionStatus.notDetermined;
  bool grantOnRequest = true;
  int requests = 0;
  int openSettingsCalls = 0;

  @override
  Future<CalendarPermissionStatus> getStatus() async => status;

  @override
  Future<bool> requestPermission() async {
    requests++;
    if (grantOnRequest) status = CalendarPermissionStatus.granted;
    return grantOnRequest;
  }

  @override
  Future<void> openSettings() async => openSettingsCalls++;
}

class _MockCalendar extends Mock implements CalendarService {}

void main() {
  late InMemorySettingsRepository settings;
  late _FakePermissions permissions;
  late _MockCalendar calendar;
  late CalendarSyncController controller;
  var queries = 0;

  setUp(() {
    settings = InMemorySettingsRepository();
    permissions = _FakePermissions();
    calendar = _MockCalendar();
    queries = 0;
    when(() => calendar.getEvents(any(), any())).thenAnswer((_) async {
      queries++;
      return <CalendarEvent>[];
    });
    controller = CalendarSyncController(
      settingsRepository: settings,
      permissionService: permissions,
      calendarService: calendar,
    );
  });

  tearDown(() => controller.dispose());

  int eventQueries() => queries;

  test('starts disconnected and does not query the calendar', () async {
    await controller.refresh();
    expect(controller.state, CalendarConnectionState.disconnected);
    expect(queries, 0);
  });

  test(
    'connect: grants permission, turns sync + meeting detection on',
    () async {
      final ok = await controller.connect();
      expect(ok, isTrue);
      expect(controller.state, CalendarConnectionState.connected);
      expect(settings.currentSettings.calendarEnabled, isTrue);
      expect(settings.currentSettings.detectMeetings, isTrue);
      expect(permissions.requests, 1);
    },
  );

  test(
    'denied permission keeps sync off and reports permission needed',
    () async {
      permissions
        ..grantOnRequest = false
        ..status = CalendarPermissionStatus.denied;
      final ok = await controller.connect();
      expect(ok, isFalse);
      expect(settings.currentSettings.calendarEnabled, isFalse);
    },
  );

  test(
    'blocked at system level opens System Settings instead of asking',
    () async {
      permissions.status = CalendarPermissionStatus.permanentlyDenied;
      final ok = await controller.connect();
      expect(ok, isFalse);
      expect(permissions.requests, 0);
      expect(permissions.openSettingsCalls, 1);
    },
  );

  test(
    'permission recovery: enabled but revoked, then granted again',
    () async {
      await controller.connect();
      permissions.status = CalendarPermissionStatus.permanentlyDenied;
      await controller.refresh(force: true);
      expect(controller.state, CalendarConnectionState.permissionBlocked);

      permissions.status = CalendarPermissionStatus.granted;
      await controller.refresh(force: true);
      expect(controller.state, CalendarConnectionState.connected);
    },
  );

  test('disconnect and reconnect', () async {
    await controller.connect();
    await controller.disconnect();
    expect(controller.state, CalendarConnectionState.disconnected);
    expect(settings.currentSettings.calendarEnabled, isFalse);
    expect(settings.currentSettings.detectMeetings, isFalse);
    expect(controller.events, isNull);

    expect(await controller.connect(), isTrue);
    expect(controller.state, CalendarConnectionState.connected);
  });

  test('concurrent refreshes share one query', () async {
    await controller.connect();
    queries = 0;
    await Future.wait([
      controller.refresh(force: true),
      controller.refresh(force: true),
      controller.refresh(force: true),
    ]);
    expect(eventQueries(), 1);
  });

  test('non-forced refreshes are throttled', () {
    fakeAsync((async) {
      var now = DateTime(2026, 3, 10, 9);
      withClock(Clock(() => now), () {
        controller.connect();
        async.flushMicrotasks();
        queries = 0;

        controller.refresh();
        async.flushMicrotasks();
        expect(eventQueries(), 0, reason: 'within 30s of the last sync');

        now = now.add(const Duration(seconds: 31));
        controller.refresh();
        async.flushMicrotasks();
        expect(eventQueries(), 1);
      });
    });
  });

  test('unrelated settings saves do not query the calendar', () async {
    await controller.connect();
    queries = 0;
    for (var i = 0; i < 5; i++) {
      await settings.save(
        settings.currentSettings.copyWith(dailyBreakGoalCount: 5 + i),
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(eventQueries(), 0);
  });

  test('sync preference persists through the shared settings', () async {
    await controller.connect();
    await controller.setQuietDuringMeetings(false);
    expect(controller.quietDuringMeetings, isFalse);
    expect(settings.currentSettings.detectMeetings, isFalse);
    expect(settings.currentSettings.calendarEnabled, isTrue);
  });

  test('a failing event query surfaces an error state', () async {
    await controller.connect();
    when(() => calendar.getEvents(any(), any())).thenThrow(Exception('boom'));
    await controller.refresh(force: true);
    expect(controller.state, CalendarConnectionState.error);
  });

  test('SettingsModel default is disconnected', () {
    expect(const SettingsModel().calendarEnabled, isFalse);
  });
}
