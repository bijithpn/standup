import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/native/native_bridge.dart';

class MacOSBridge implements NativeBridgePlatform {
  final MethodChannel _channel = const MethodChannel(
    'com.breakmate.desktop/bridge',
  );
  static final Set<String> _loggedMissingMethods = {};

  /// Show the native multi-monitor overlay
  @override
  Future<void> showOverlay([Map<String, dynamic>? args]) async {
    await _invokeSafely('showOverlay', args);
  }

  /// Hide the native multi-monitor overlay
  @override
  Future<void> hideOverlay({bool restoreMainWindow = true}) async {
    await _invokeSafely('hideOverlay', {
      'restoreMainWindow': restoreMainWindow,
    });
  }

  /// Skip the current break from the overlay and sync to main engine
  @override
  Future<void> skipBreak() async {
    await _invokeSafely('skipBreak');
  }

  /// Set the visual effect (vibrancy) of the overlays
  @override
  Future<void> setVisualEffect(String material) async {
    await _invokeSafely('setVisualEffect', {'material': material});
  }

  /// Focus the application and un-minimize if needed
  @override
  Future<void> focusApp() async {
    await _invokeSafely('focusApp');
  }

  /// Set the window level (e.g., 'screenSaver', 'floating', 'normal')
  @override
  Future<void> setWindowLevel(String level) async {
    await _invokeSafely('setWindowLevel', {'level': level});
  }

  /// Set presentation options for the application
  @override
  Future<void> setPresentationOptions({
    required bool hideDock,
    required bool hideMenu,
  }) async {
    await _invokeSafely('setPresentationOptions', {
      'hideDock': hideDock,
      'hideMenu': hideMenu,
    });
  }

  /// Get the system idle time in seconds
  @override
  Future<double> getIdleTime() async {
    final double? idleTime = await _invokeSafely<double>('getIdleTime');
    return idleTime ?? 0.0;
  }

  /// Get the current macOS appearance ('dark' or 'light')
  @override
  Future<String> getAppearance() async {
    final String? appearance = await _invokeSafely<String>('getAppearance');
    return appearance ?? 'light';
  }

  /// Set the overlay to ignore mouse events (click-through)
  @override
  Future<void> setIgnoreMouseEvents(bool ignore) async {
    await _invokeSafely('setIgnoreMouseEvents', {'ignore': ignore});
  }

  /// Update data in all active overlay engines
  @override
  Future<void> updateOverlayData(Map<String, dynamic> data) async {
    await _invokeSafely('updateOverlayData', data);
  }

  /// Spawns the native floating desktop companion window
  @override
  Future<void> showCompanion(Map<String, dynamic> args) async {
    await _invokeSafely('showCompanion', args);
  }

  /// Closes the native floating desktop companion window
  @override
  Future<void> hideCompanion() async {
    await _invokeSafely('hideCompanion');
  }

  /// Sets companion window click-through mode
  @override
  Future<void> setCompanionClickThrough(bool ignore) async {
    await _invokeSafely('setCompanionClickThrough', {'ignore': ignore});
  }

  /// Updates companion scale and native dimensions
  @override
  Future<void> updateCompanionScale(double scale) async {
    await _invokeSafely('updateCompanionScale', {'scale': scale});
  }

  /// Swaps companion theme dynamically
  @override
  Future<void> updateCompanionTheme(String themeId) async {
    await _invokeSafely('updateCompanionTheme', {'themeId': themeId});
  }

  /// Updates companion display metadata.
  @override
  Future<void> updateCompanionName(String petName) async {
    await _invokeSafely('updateCompanionName', {'petName': petName});
  }

  /// Triggers a dynamic behavioral animation state in the companion overlay
  @override
  Future<void> triggerCompanionState(String stateName) async {
    await _invokeSafely('triggerCompanionState', {'state': stateName});
  }

  /// Sets wandering AI state in the companion overlay
  @override
  Future<void> setCompanionWandering(bool enabled) async {
    await _invokeSafely('setCompanionWandering', {'enabled': enabled});
  }

  /// Sets follow mouse cursor state in the companion overlay
  @override
  Future<void> setCompanionFollowMouse(bool enabled) async {
    await _invokeSafely('setCompanionFollowMouse', {'enabled': enabled});
  }

  @override
  Future<bool> requestCalendarPermissions() async {
    debugPrint('🔥 Requesting calendar permission');
    final bool? result = await _invokeSafely<bool>('requestCalendarPermissions');
    debugPrint('🔥 Permission result: $result');
    return result ?? false;
  }

  @override
  Future<bool> hasCalendarPermissions() async {
    final bool? granted = await _invokeSafely<bool>('hasCalendarPermissions');
    return granted ?? false;
  }

  @override
  Future<String> getCalendarPermissionStatus() async {
    final String? status = await _invokeSafely<String>(
      'getCalendarPermissionStatus',
    );
    return status ?? 'denied';
  }

  @override
  Future<void> openCalendarSettings() async {
    await _invokeSafely('openCalendarSettings');
  }

  @override
  Future<List<Map<String, dynamic>>> getUpcomingCalendarEvents(int windowMinutes) async {
    final List<dynamic>? events = await _invokeSafely<List<dynamic>>(
      'getUpcomingCalendarEvents',
      {'windowMinutes': windowMinutes},
    );
    if (events == null) return [];
    return events.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getCalendars() async {
    final List<dynamic>? calendars = await _invokeSafely<List<dynamic>>(
      'getCalendars',
    );
    if (calendars == null) return [];
    return calendars.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getEvents(
    int startMs,
    int endMs,
    List<String>? calendarIds,
  ) async {
    final List<dynamic>? events = await _invokeSafely<List<dynamic>>(
      'getEvents',
      {'startMs': startMs, 'endMs': endMs, 'calendarIds': calendarIds},
    );
    if (events == null) return [];
    return events.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<T?> _invokeSafely<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      if (_loggedMissingMethods.add(method)) {
        developer.log(
          'macOS bridge method unavailable: $method',
          name: 'BreakMate',
        );
      }
      return null;
    } catch (e, stackTrace) {
      developer.log(
        'macOS bridge method failed: $method',
        name: 'BreakMate',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
