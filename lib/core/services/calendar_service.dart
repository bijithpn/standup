import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/native/native_bridge.dart';

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

/// Service that routes calendar operations to the appropriate backend:
/// - macOS / Windows → native MethodChannel bridge (EKEventStore / stub)
class CalendarService {
  final AppLogger _logger = AppLogger();

  /// True if the current platform has a native bridge with calendar support.
  bool get _useNativeBridge =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows);

  Future<bool> requestPermissions() async {
    if (_useNativeBridge) {
      return await NativeBridge.requestCalendarPermissions();
    }
    _logger.warning(
      'Calendar permissions requested on unsupported platform: '
      '${kIsWeb ? 'web' : Platform.operatingSystem}',
    );
    return false;
  }

  Future<bool> checkPermissions() async {
    if (_useNativeBridge) {
      return await NativeBridge.hasCalendarPermissions();
    }
    return false;
  }

  Future<void> openSettings() async {
    if (_useNativeBridge) {
      await NativeBridge.openCalendarSettings();
    }
    // On unsupported platforms, no-op.
  }

  Future<List<CalendarEvent>> getUpcomingEvents({
    Duration window = const Duration(hours: 4),
  }) async {
    if (_useNativeBridge) {
      try {
        final events = await NativeBridge.getUpcomingCalendarEvents(
          window.inMinutes,
        );
        return events.map((e) => CalendarEvent(
          title: e['title'] as String? ?? 'No Title',
          start: DateTime.fromMillisecondsSinceEpoch(e['start'] as int),
          end: DateTime.fromMillisecondsSinceEpoch(e['end'] as int),
          isAllDay: e['isAllDay'] as bool? ?? false,
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
    final events = await getUpcomingEvents(window: const Duration(minutes: 1));
    final now = DateTime.now();
    return events.any(
      (e) => !e.isAllDay && e.start.isBefore(now) && e.end.isAfter(now),
    );
  }
}
