import 'package:breakmate/core/storage/models/calendar_event_model.dart';
import 'package:breakmate/core/services/calendar_repository.dart';

class CalendarEventService {
  final CalendarRepository _repository;

  CalendarEventService(this._repository);

  Future<List<CalendarEventModel>> getUpcomingEvents({
    Duration window = const Duration(hours: 4),
  }) async {
    final now = DateTime.now();
    final end = now.add(window);
    return await _repository.getEvents(now, end);
  }

  Future<List<CalendarEventModel>> getEvents(
    DateTime start,
    DateTime end, {
    List<String>? calendarIds,
  }) async {
    return await _repository.getEvents(start, end, calendarIds: calendarIds);
  }

  Future<bool> isMeetingActive() async {
    final now = DateTime.now();
    final events = await _repository.getEvents(
      now.subtract(const Duration(minutes: 1)),
      now.add(const Duration(minutes: 1)),
    );
    return events.any(
      (e) => !e.allDay && e.start.isBefore(now) && e.end.isAfter(now),
    );
  }
}
