import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/utils/logger.dart';

class MacOSBridge implements NativeBridgePlatform {
  final MethodChannel _channel = const MethodChannel(
    'com.breakmate.desktop/bridge',
  );
  static final Set<String> _loggedMissingMethods = {};
  static final AppLogger _logger = AppLogger();

  @override
  Future<void> showOverlay([OverlayArgs? args]) async {
    await _invokeSafely('showOverlay', args?.toMap());
  }

  @override
  Future<void> hideOverlay({bool restoreMainWindow = true}) async {
    await _invokeSafely('hideOverlay', {
      'restoreMainWindow': restoreMainWindow,
    });
  }

  @override
  Future<void> skipBreak() async {
    await _invokeSafely('skipBreak');
  }

  @override
  Future<void> setVisualEffect(String material) async {
    await _invokeSafely('setVisualEffect', {'material': material});
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
    await _invokeSafely('setPresentationOptions', {
      'hideDock': hideDock,
      'hideMenu': hideMenu,
    });
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
  Future<void> updateOverlayData(OverlayData data) async {
    await _invokeSafely('updateOverlayData', data.toMap());
  }

  @override
  Future<void> showCompanion(CompanionArgs args) async {
    await _invokeSafely('showCompanion', args.toMap());
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
    debugPrint('Requesting calendar permission');
    final bool? result = await _invokeSafely<bool>(
      'requestCalendarPermissions',
    );
    debugPrint('Calendar permission result: $result');
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

  @override
  Future<List<NativeDisplayInfo>> enumerateDisplays() async {
    final List<dynamic>? displays = await _invokeSafely<List<dynamic>>(
      'enumerateDisplays',
    );
    if (displays == null) return [];
    return displays
        .map((e) => NativeDisplayInfo.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  void registerDisplayChangeCallback(
    void Function(List<NativeDisplayInfo>) cb,
  ) {
    const EventChannel eventChannel = EventChannel(
      'com.breakmate.desktop/displayChange',
    );
    eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is List) {
          final displays = event
              .map((e) => NativeDisplayInfo.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
          cb(displays);
        }
      },
      onError: (Object error) {
        developer.log(
          'macOS displayChange event error: $error',
          name: 'BreakMate',
        );
      },
    );
  }

  /// macOS uses screen-bottom origin; the caller is responsible for
  @override
  Future<Offset> getCursorPosition() async {
    final Map<dynamic, dynamic>? result =
        await _invokeSafely<Map<dynamic, dynamic>>('getCursorPosition');
    if (result == null) return Offset.zero;
    final double x = (result['x'] as num?)?.toDouble() ?? 0.0;
    final double y = (result['y'] as num?)?.toDouble() ?? 0.0;
    return Offset(x, y);
  }

  @override
  Future<List<WindowInfo>> getVisibleWindows() async {
    final List<dynamic>? windows = await _invokeSafely<List<dynamic>>(
      'getVisibleWindows',
    );
    if (windows == null) return [];
    return windows
        .map((e) => WindowInfo.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> showConstraintWindow(ConstraintWindowArgs args) async {
    await _invokeSafely('showConstraintWindow', args.toMap());
  }

  @override
  Future<void> hideConstraintWindow() async {
    await _invokeSafely('hideConstraintWindow');
  }

  @override
  void registerConstraintWindowBoundsCallback(
    void Function(ConstraintWindowArgs) callback,
  ) {
    const EventChannel eventChannel = EventChannel(
      'com.breakmate.desktop/constraintWindowBounds',
    );
    eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          callback(ConstraintWindowArgs.fromMap(Map<String, dynamic>.from(event)));
        }
      },
      onError: (Object error) {
        developer.log(
          'macOS constraintWindowBounds event error: $error',
          name: 'BreakMate',
        );
      },
    );
  }

  @override
  Future<void> showPipWindow(PipWindowArgs args) async {
    await _invokeSafely('showPipWindow', args.toMap());
  }

  @override
  Future<void> hidePipWindow() async {
    await _invokeSafely('hidePipWindow');
  }

  Future<T?> _invokeSafely<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      if (_loggedMissingMethods.add(method)) {
        _logger.error('macOS bridge method unavailable: $method');
      }
      return null;
    } catch (e, stackTrace) {
      _logger.error(
        'macOS bridge method failed: $method',
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
