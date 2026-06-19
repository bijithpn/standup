import 'package:flutter/foundation.dart';
import 'package:breakmate/core/native/native_bridge.dart';

enum CalendarPermissionStatus {
  notDetermined,
  restricted,
  denied,
  permanentlyDenied,
  granted,
}

class CalendarPermissionService {
  final NativeBridgePlatform _platform;

  CalendarPermissionService({NativeBridgePlatform? platform})
    : _platform = platform ?? NativeBridge.instance;

  bool _requestedInThisSession = false;

  Future<CalendarPermissionStatus> getStatus() async {
    try {
      final String statusStr = await _platform.getCalendarPermissionStatus();
      switch (statusStr) {
        case 'notDetermined':
          return CalendarPermissionStatus.notDetermined;
        case 'restricted':
          return CalendarPermissionStatus.restricted;
        case 'denied':
          if (_requestedInThisSession) {
            return CalendarPermissionStatus.denied;
          }
          return CalendarPermissionStatus.permanentlyDenied;
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
      _requestedInThisSession = true;
      final bool granted = await _platform.requestCalendarPermissions();
      return granted;
    } catch (e) {
      debugPrint('[CalendarPermissionService] Error requesting permission: $e');
      return false;
    }
  }

  void resetRequestSession() {
    _requestedInThisSession = false;
  }

  Future<void> openSettings() async {
    try {
      await _platform.openCalendarSettings();
    } catch (e) {
      debugPrint(
        '[CalendarPermissionService] Error opening calendar settings: $e',
      );
    }
  }
}
