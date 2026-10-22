import 'dart:async';
import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/calendar/calendar_sync_controller.dart';

/// Presents Calendar Sync state to the Today screen. The state itself lives in
/// [CalendarSyncController]; this class only adapts it and nudges a throttled
/// refresh while the screen is visible.
class DashboardController extends ChangeNotifier with WidgetsBindingObserver {
  final CalendarSyncController _calendar = sl<CalendarSyncController>();
  Timer? _refreshTimer;

  List<CalendarEvent>? get calendarEvents => _calendar.events;
  bool get calendarLoading =>
      _calendar.isLoadingEvents ||
      _calendar.state == CalendarConnectionState.checking;
  bool get calendarPermissionGranted =>
      _calendar.permission == CalendarPermissionStatus.granted;
  bool get calendarPermissionDenied =>
      _calendar.enabled &&
      _calendar.permission != CalendarPermissionStatus.granted &&
      _calendar.permission != CalendarPermissionStatus.notDetermined;
  bool get isRequestingPermission => _calendar.isRequesting;

  DashboardController() {
    WidgetsBinding.instance.addObserver(this);
    _calendar.addListener(notifyListeners);
    loadCalendarEvents();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      loadCalendarEvents();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadCalendarEvents();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _calendar.removeListener(notifyListeners);
    super.dispose();
  }

  Future<void> loadCalendarEvents() async {
    if (!_calendar.enabled) return;
    await _calendar.refresh();
  }

  Future<bool> requestCalendarAccess() => _calendar.connect();
}
