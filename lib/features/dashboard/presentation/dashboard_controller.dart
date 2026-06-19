import 'dart:async';
import 'package:flutter/material.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class DashboardController extends ChangeNotifier with WidgetsBindingObserver {
  List<CalendarEvent>? calendarEvents;
  bool calendarLoading = false;
  bool calendarPermissionGranted = false;
  bool calendarPermissionDenied = false;
  bool isRequestingPermission = false;
  Timer? _refreshTimer;

  DashboardController() {
    WidgetsBinding.instance.addObserver(this);
    loadCalendarEvents();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      loadCalendarEvents();
    });
    sl<SettingsRepository>().addListener(loadCalendarEvents);
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
    sl<SettingsRepository>().removeListener(loadCalendarEvents);
    super.dispose();
  }

  Future<void> loadCalendarEvents() async {
    final settings = sl<SettingsRepository>().currentSettings;
    if (!settings.calendarEnabled) {
      calendarEvents = null;
      calendarLoading = false;
      notifyListeners();
      return;
    }

    final calendarService = sl<CalendarService>();
    calendarLoading = true;
    notifyListeners();

    try {
      final hasPermission = await calendarService.checkPermissions();
      if (!hasPermission) {
        calendarPermissionGranted = false;
        calendarLoading = false;
        notifyListeners();
        return;
      }

      calendarPermissionGranted = true;
      calendarPermissionDenied = false; // Reset if confirmed

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

      calendarEvents = await calendarService.getEvents(startOfToday, endOfToday);
      calendarLoading = false;
      notifyListeners();
    } catch (_) {
      calendarLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestCalendarAccess() async {
    if (isRequestingPermission) return false;

    isRequestingPermission = true;
    notifyListeners();

    bool granted = false;
    try {
      final calendarService = sl<CalendarService>();
      granted = await calendarService.requestPermissions();

      if (granted) {
        calendarPermissionGranted = true;
        calendarPermissionDenied = false;
        await loadCalendarEvents();
      } else {
        calendarPermissionGranted = false;
        calendarPermissionDenied = true;
      }
    } finally {
      isRequestingPermission = false;
      notifyListeners();
    }
    
    return granted;
  }
}
