import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

enum CalendarConnectionState {
  /// Permission/status check in progress.
  checking,

  /// Sync is turned off in BreakMate.
  disconnected,

  /// Sync is on and macOS has granted access.
  connected,

  /// Sync is on but macOS access is missing; the user can grant or open
  /// System Settings.
  permissionNeeded,

  /// Access is blocked at system level (denied before / restricted).
  permissionBlocked,

  /// Connected, but the last event query failed.
  error,
}

/// The single owner of Calendar Sync: connection state, permission, sync
/// preferences, and the (de-duplicated, throttled) event query that every
/// screen — Calendar Sync settings, Today, Focus Mode — reads from.
class CalendarSyncController extends ChangeNotifier {
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

  /// Only a real on/off change touches the calendar; the many unrelated
  /// settings saves (every slider drag) must not trigger a native query.
  void _onSettingsChanged() {
    final now = enabled;
    if (now == _lastEnabled) {
      notifyListeners(); // quietDuringMeetings may have changed
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

  /// Re-reads permission and, when connected, today's events. Concurrent calls
  /// share one in-flight query; calls within [minRefreshInterval] of the last
  /// successful sync are skipped unless [force].
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

  /// Requests macOS access (or opens System Settings if it can no longer be
  /// requested) and turns sync on when granted.
  Future<bool> connect() async {
    if (_requesting) return false;
    _requesting = true;
    notifyListeners();
    try {
      var status = await _permissions.getStatus();
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

  /// Turns sync off. macOS keeps the permission it already granted; only the
  /// user can revoke it in System Settings.
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
