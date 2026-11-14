import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

/// UI-facing summary of calendar permission + sync status, derived in [CalendarSyncController.state].
enum CalendarConnectionState {
  checking,

  disconnected,

  connected,

  permissionNeeded,

  permissionBlocked,

  error,
}

/// Owns calendar permission and today's events; shared by Settings and Dashboard.
/// Enabling/disabling is driven by [SettingsRepository.calendarEnabled].
class CalendarSyncController extends ChangeNotifier {
  // Throttle for non-forced refreshes so UI rebuilds don't hit the native calendar API.
  static const Duration minRefreshInterval = Duration(seconds: 30);

  final SettingsRepository _settingsRepo;
  final CalendarPermissionService _permissions;
  final CalendarService _calendar;

  CalendarPermissionStatus _permission = CalendarPermissionStatus.notDetermined;
  bool _checking = false;
  bool _requesting = false;
  bool _loadingEvents = false;
  List<CalendarEvent>? _events;
  DateTime? _lastSyncedAt;
  Object? _error;
  Future<void>? _inFlight;
  bool _lastEnabled;

  CalendarSyncController({
    required SettingsRepository settingsRepository,
    required CalendarPermissionService permissionService,
    required CalendarService calendarService,
  }) : _settingsRepo = settingsRepository,
       _permissions = permissionService,
       _calendar = calendarService,
       _lastEnabled = settingsRepository.currentSettings.calendarEnabled {
    _settingsRepo.addListener(_onSettingsChanged);
  }

  bool get enabled => _settingsRepo.currentSettings.calendarEnabled;
  bool get quietDuringMeetings => _settingsRepo.currentSettings.detectMeetings;
  CalendarPermissionStatus get permission => _permission;
  bool get isRequesting => _requesting;
  bool get isLoadingEvents => _loadingEvents;
  List<CalendarEvent>? get events => _events;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  Object? get error => _error;

  CalendarConnectionState get state {
    if (_checking) return CalendarConnectionState.checking;
    if (!enabled) return CalendarConnectionState.disconnected;
    switch (_permission) {
      case CalendarPermissionStatus.granted:
        return _error != null
            ? CalendarConnectionState.error
            : CalendarConnectionState.connected;
      case CalendarPermissionStatus.notDetermined:
      case CalendarPermissionStatus.denied:
        return CalendarConnectionState.permissionNeeded;
      case CalendarPermissionStatus.permanentlyDenied:
      case CalendarPermissionStatus.restricted:
        return CalendarConnectionState.permissionBlocked;
    }
  }

  // Fetch on enable, drop cached events on disable; other setting changes just rebuild listeners.
  void _onSettingsChanged() {
    final now = enabled;
    if (now == _lastEnabled) {
      notifyListeners();
      return;
    }
    _lastEnabled = now;
    if (now) {
      unawaited(refresh(force: true));
    } else {
      _events = null;
      _error = null;
      notifyListeners();
    }
  }

  /// Reloads today's events; concurrent calls share one in-flight future.
  Future<void> refresh({bool force = false}) {
    final running = _inFlight;
    if (running != null) return running;
    if (!force &&
        _lastSyncedAt != null &&
        clock.now().difference(_lastSyncedAt!) < minRefreshInterval) {
      return Future.value();
    }
    final future = _refresh().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<void> _refresh() async {
    // Defer so notifyListeners never fires synchronously during a widget build.
    await Future<void>.value();
    _checking = _permission == CalendarPermissionStatus.notDetermined;
    notifyListeners();
    try {
      _permission = await _permissions.getStatus();
    } catch (_) {
      _permission = CalendarPermissionStatus.denied;
    }
    _checking = false;

    if (!enabled || _permission != CalendarPermissionStatus.granted) {
      _events = null;
      _error = null;
      notifyListeners();
      return;
    }

    _loadingEvents = true;
    notifyListeners();
    try {
      final now = clock.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day + 1);
      _events = await _calendar.getEvents(start, end);
      _lastSyncedAt = clock.now();
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _loadingEvents = false;
      notifyListeners();
    }
  }

  Future<List<CalendarEvent>> eventsBetween(DateTime start, DateTime end) =>
      _calendar.getEvents(start, end);

  /// Requests calendar permission (or opens system settings if blocked) and enables sync + meeting detection on success.
  Future<bool> connect() async {
    if (_requesting) return false;
    _requesting = true;
    notifyListeners();
    try {
      var status = await _permissions.getStatus();

      if (status == CalendarPermissionStatus.permanentlyDenied) {
        final granted = await _permissions.requestPermission();
        status = granted
            ? CalendarPermissionStatus.granted
            : CalendarPermissionStatus.permanentlyDenied;
      }
      if (status == CalendarPermissionStatus.permanentlyDenied ||
          status == CalendarPermissionStatus.restricted) {
        _permission = status;
        await _permissions.openSettings();
        return false;
      }
      if (status != CalendarPermissionStatus.granted) {
        final granted = await _permissions.requestPermission();
        status = granted
            ? CalendarPermissionStatus.granted
            : await _permissions.getStatus();
      }

      // A denied answer after our prompt means the OS won't prompt again.
      if (status == CalendarPermissionStatus.denied) {
        status = CalendarPermissionStatus.permanentlyDenied;
      }
      _permission = status;
      if (status != CalendarPermissionStatus.granted) return false;

      await _settingsRepo.save(
        _settingsRepo.currentSettings.copyWith(
          calendarEnabled: true,
          detectMeetings: true,
        ),
      );
      await refresh(force: true);
      return true;
    } finally {
      _requesting = false;
      notifyListeners();
    }
  }

  /// Turns off calendar sync and meeting detection; the settings listener clears cached events.
  Future<void> disconnect() async {
    await _settingsRepo.save(
      _settingsRepo.currentSettings.copyWith(
        calendarEnabled: false,
        detectMeetings: false,
      ),
    );
  }

  Future<void> setQuietDuringMeetings(bool value) => _settingsRepo.save(
    _settingsRepo.currentSettings.copyWith(detectMeetings: value),
  );

  Future<void> openSystemSettings() => _permissions.openSettings();

  @override
  void dispose() {
    _settingsRepo.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
