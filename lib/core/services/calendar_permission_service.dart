import 'package:flutter/foundation.dart';
import 'package:breakmate/core/native/native_bridge.dart';

enum CalendarPermissionStatus { notDetermined, restricted, denied, granted }

class CalendarPermissionService {
  Future<CalendarPermissionStatus> getStatus() async {
    try {
      final String statusStr = await NativeBridge.getCalendarPermissionStatus();
      switch (statusStr) {
        case 'notDetermined':
          return CalendarPermissionStatus.notDetermined;
        case 'restricted':
          return CalendarPermissionStatus.restricted;
        case 'denied':
          return CalendarPermissionStatus.denied;
        case 'granted':
          return CalendarPermissionStatus.granted;
        default:
          return CalendarPermissionStatus.denied;
      }
    } catch (e) {
      debugPrint(
        '[CalendarPermissionService] Error getting permission status: $e',
      );
      return CalendarPermissionStatus.denied;
    }
  }

  Future<bool> requestPermission() async {
    try {
      return await NativeBridge.requestCalendarPermissions();
    } catch (e) {
      debugPrint('[CalendarPermissionService] Error requesting permission: $e');
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await NativeBridge.openCalendarSettings();
    } catch (e) {
      debugPrint(
        '[CalendarPermissionService] Error opening calendar settings: $e',
      );
    }
  }
}
