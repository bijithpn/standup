import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:breakmate/core/native/native_bridge.dart';

/// Windows implementation of the platform native bridge interface.
class WindowsBridge implements NativeBridgePlatform {
  static const MethodChannel _channel = MethodChannel(
    'com.breakmate.desktop/bridge',
  );
  static final Set<String> _loggedMissingMethods = {};

  @override
  Future<void> showOverlay([Map<String, dynamic>? args]) async {
    await _invokeSafely('showOverlay', args);
  }

  @override
  Future<void> hideOverlay({bool restoreMainWindow = true}) async {
    await _invokeSafely('hideOverlay', {
      'restoreMainWindow': restoreMainWindow,
    });
  }

  @override
  Future<void> skipBreak() async {
    // Windows fallback: no-op / graceful log
    developer.log('skipBreak not supported on Windows', name: 'BreakMate');
  }

  @override
  Future<void> setVisualEffect(String material) async {
    // Windows fallback: no-op / graceful log
    developer.log(
      'setVisualEffect not supported on Windows',
      name: 'BreakMate',
    );
  }

  @override
  Future<void> focusApp() async {
    await _invokeSafely('focusApp');
  }

  @override
  Future<void> setWindowLevel(String level) async {
    await _invokeSafely('setWindowLevel', {'level': level});
  }

  @override
  Future<void> setPresentationOptions({
    required bool hideDock,
    required bool hideMenu,
  }) async {
    // Windows fallback: no-op / graceful log
    developer.log(
      'setPresentationOptions not supported on Windows',
      name: 'BreakMate',
    );
  }

  @override
  Future<double> getIdleTime() async {
    final double? idleTime = await _invokeSafely<double>('getIdleTime');
    return idleTime ?? 0.0;
  }

  @override
  Future<String> getAppearance() async {
    final String? appearance = await _invokeSafely<String>('getAppearance');
    return appearance ?? 'light';
  }

  @override
  Future<void> setIgnoreMouseEvents(bool ignore) async {
    await _invokeSafely('setIgnoreMouseEvents', {'ignore': ignore});
  }

  @override
  Future<void> updateOverlayData(Map<String, dynamic> data) async {
    await _invokeSafely('updateOverlayData', data);
  }

  @override
  Future<void> showCompanion(Map<String, dynamic> args) async {
    await _invokeSafely('showCompanion', args);
  }

  @override
  Future<void> hideCompanion() async {
    await _invokeSafely('hideCompanion');
  }

  @override
  Future<void> setCompanionClickThrough(bool ignore) async {
    await _invokeSafely('setCompanionClickThrough', {'ignore': ignore});
  }

  @override
  Future<void> updateCompanionScale(double scale) async {
    await _invokeSafely('updateCompanionScale', {'scale': scale});
  }

  @override
  Future<void> updateCompanionTheme(String themeId) async {
    await _invokeSafely('updateCompanionTheme', {'themeId': themeId});
  }

  @override
  Future<void> updateCompanionName(String petName) async {
    await _invokeSafely('updateCompanionName', {'petName': petName});
  }

  @override
  Future<void> triggerCompanionState(String stateName) async {
    await _invokeSafely('triggerCompanionState', {'state': stateName});
  }

  @override
  Future<void> setCompanionWandering(bool enabled) async {
    await _invokeSafely('setCompanionWandering', {'enabled': enabled});
  }

  @override
  Future<void> setCompanionFollowMouse(bool enabled) async {
    await _invokeSafely('setCompanionFollowMouse', {'enabled': enabled});
  }

  @override
  Future<bool> requestCalendarPermissions() async {
    final bool? granted = await _invokeSafely<bool>(
      'requestCalendarPermissions',
    );
    return granted ?? false;
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
  Future<List<Map<String, dynamic>>> getUpcomingCalendarEvents(
    int windowMinutes,
  ) async {
    final List<dynamic>? events = await _invokeSafely<List<dynamic>>(
      'getUpcomingCalendarEvents',
      {'windowMinutes': windowMinutes},
    );
    if (events == null) return [];
    return events.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> openCalendarSettings() async {
    await _invokeSafely('openCalendarSettings');
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

  static Future<T?> _invokeSafely<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      if (_loggedMissingMethods.add(method)) {
        developer.log(
          'Windows bridge method unavailable: $method',
          name: 'BreakMate',
        );
      }
      return null;
    } catch (e, stackTrace) {
      developer.log(
        'Windows bridge method failed: $method',
        name: 'BreakMate',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
