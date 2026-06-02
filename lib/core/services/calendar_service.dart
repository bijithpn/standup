import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/services/calendar_permission_service.dart';
import 'package:breakmate/core/services/calendar_event_service.dart';

class CalendarEvent {
  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;

  CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    this.isAllDay = false,
  });
}

/// Service that routes calendar operations to the appropriate backend.
/// Preserves the original public API for backward compatibility.
class CalendarService {
  final AppLogger _logger = AppLogger();
  final CalendarPermissionService _permissionService;
  final CalendarEventService _eventService;

  CalendarService({
    required CalendarPermissionService permissionService,
    required CalendarEventService eventService,
  })  : _permissionService = permissionService,
        _eventService = eventService;

  /// True if the current platform has a native bridge with calendar support.
  bool get _useNativeBridge =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows);

  Future<bool> requestPermissions() async {
    if (_useNativeBridge) {
      return await _permissionService.requestPermission();
    }
    _logger.warning(
      'Calendar permissions requested on unsupported platform: '
      '${kIsWeb ? 'web' : Platform.operatingSystem}',
    );
    return false;
  }

  Future<bool> checkPermissions() async {
    if (_useNativeBridge) {
      final status = await _permissionService.getStatus();
      return status == CalendarPermissionStatus.granted;
    }
    return false;
  }

  Future<void> openSettings() async {
    if (_useNativeBridge) {
      await _permissionService.openSettings();
    }
  }

  Future<List<CalendarEvent>> getUpcomingEvents({
    Duration window = const Duration(hours: 4),
  }) async {
    if (_useNativeBridge) {
      try {
        final events = await _eventService.getUpcomingEvents(window: window);
        return events.map((e) => CalendarEvent(
          title: e.title.isEmpty ? 'No Title' : e.title,
          start: e.start,
          end: e.end,
          isAllDay: e.allDay,
        )).toList();
      } catch (e) {
        _logger.error('Failed to fetch native calendar events: $e');
        return [];
      }
    }
    return [];
  }

  Future<bool> isMeetingActive() async {
    if (!_useNativeBridge) return false;
    return await _eventService.isMeetingActive();
  }
}
