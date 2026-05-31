import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:breakmate/core/utils/logger.dart';

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

class CalendarService {
  final DeviceCalendar _deviceCalendarPlugin = DeviceCalendar();
  final AppLogger _logger = AppLogger();

  Future<bool> requestPermissions() async {
    final status = await _deviceCalendarPlugin.requestPermissions();
    return status == CalendarPermissionStatus.granted;
  }

  Future<bool> checkPermissions() async {
    try {
      final status = await _deviceCalendarPlugin.hasPermissions();
      return status == CalendarPermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  Future<List<CalendarEvent>> getUpcomingEvents({Duration window = const Duration(hours: 4)}) async {
    try {
      final status = await _deviceCalendarPlugin.hasPermissions();
      if (status != CalendarPermissionStatus.granted) {
        return [];
      }

      final now = DateTime.now();
      final end = now.add(window);

      // device_calendar_plus 0.4.0 listEvents uses positional DateTime args
      final eventsResult = await _deviceCalendarPlugin.listEvents(now, end);

      return eventsResult.map((event) => CalendarEvent(
        title: event.title,
        start: event.startDate,
        end: event.endDate,
        isAllDay: event.isAllDay,
      )).toList();
    } catch (e) {
      _logger.error('Failed to fetch calendar events: $e');
      return [];
    }
  }


  Future<bool> isMeetingActive() async {
    final events = await getUpcomingEvents(window: const Duration(minutes: 1));
    final now = DateTime.now();
    return events.any((e) => !e.isAllDay && e.start.isBefore(now) && e.end.isAfter(now));
  }
}
