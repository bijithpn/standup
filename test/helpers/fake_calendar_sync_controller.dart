import 'package:flutter/foundation.dart';

import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';

/// Stand-in for [CalendarSyncController] in widget tests that only render its
/// state. Every member not overridden here is unsupported.
class FakeCalendarSyncController extends ChangeNotifier
    implements CalendarSyncController {
  FakeCalendarSyncController({
    this.fakeState = CalendarConnectionState.disconnected,
    this.fakePermission = CalendarPermissionStatus.notDetermined,
  });

  CalendarConnectionState fakeState;
  CalendarPermissionStatus fakePermission;
  int refreshCalls = 0;
  int openSettingsCalls = 0;

  @override
  CalendarConnectionState get state => fakeState;
  @override
  CalendarPermissionStatus get permission => fakePermission;
  @override
  bool get enabled => fakeState != CalendarConnectionState.disconnected;
  @override
  bool get quietDuringMeetings => false;
  @override
  bool get isRequesting => false;
  @override
  bool get isLoadingEvents => false;
  @override
  List<CalendarEvent>? get events => null;
  @override
  DateTime? get lastSyncedAt => null;
  @override
  Object? get error => null;

  @override
  Future<void> refresh({bool force = false}) async => refreshCalls++;
  @override
  Future<void> openSystemSettings() async => openSettingsCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
