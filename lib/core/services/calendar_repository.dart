import 'package:flutter/foundation.dart';
import 'package:breakmate/core/storage/models/calendar_model.dart';
import 'package:breakmate/core/storage/models/calendar_event_model.dart';
import 'package:breakmate/core/native/native_bridge.dart';

class CalendarRepository {
  Future<List<CalendarModel>> getCalendars() async {
    try {
      final List<Map<String, dynamic>> result = await NativeBridge.getCalendars();
      return result.map((e) => CalendarModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[CalendarRepository] Error getting calendars: $e');
      return [];
    }
  }

  Future<List<CalendarEventModel>> getEvents(
    DateTime start,
    DateTime end, {
    List<String>? calendarIds,
  }) async {
    try {
      final List<Map<String, dynamic>> result = await NativeBridge.getEvents(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        calendarIds,
      );
      return result.map((e) => CalendarEventModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[CalendarRepository] Error getting events: $e');
      return [];
    }
  }
}
