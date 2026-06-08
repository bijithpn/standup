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

  /// Enumerates connected displays.
  /// Returns maps with keys: {id, x, y, width, height, dpiScale, isPrimary}.
  @override
  Future<List<Map<String, dynamic>>> enumerateDisplays() async {
    const channel = MethodChannel('com.breakmate/display_bridge');
    try {
      final List<dynamic>? displays = await channel.invokeMethod<List<dynamic>>(
        'getDisplays',
      );
      if (displays == null) return [];
      return displays.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return {
          'id': map['id'] ?? '',
          'x': map['boundsX'] ?? 0.0,
          'y': map['boundsY'] ?? 0.0,
          'width': map['width'] ?? 0.0,
          'height': map['height'] ?? 0.0,
          'dpiScale': map['pixelRatio'] ?? 1.0,
          'isPrimary': map['isPrimary'] ?? false,
        };
      }).toList();
    } catch (e, stackTrace) {
      developer.log(
        'Windows display bridge enumerateDisplays failed',
        name: 'BreakMate',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Registers a native callback for display change notifications (WM_DISPLAYCHANGE).
  /// Uses EventChannel 'com.breakmate/display_events'.
  @override
  void registerDisplayChangeCallback(
    void Function(List<Map<String, dynamic>>) cb,
  ) {
    const EventChannel eventChannel = EventChannel(
      'com.breakmate/display_events',
    );
    eventChannel.receiveBroadcastStream().listen(
      (dynamic event) async {
        final displays = await enumerateDisplays();
        cb(displays);
      },
      onError: (Object error) {
        developer.log(
          'Windows displayChange event error: $error',
          name: 'BreakMate',
        );
      },
    );
  }

  /// Returns the current global cursor position via GetCursorPos().
  @override
  Future<Offset> getCursorPosition() async {
    final Map<dynamic, dynamic>? result =
        await _invokeSafely<Map<dynamic, dynamic>>('getCursorPosition');
    if (result == null) return Offset.zero;
    final double x = (result['x'] as num?)?.toDouble() ?? 0.0;
    final double y = (result['y'] as num?)?.toDouble() ?? 0.0;
    return Offset(x, y);
  }

  /// Returns visible, non-minimized application windows via EnumWindows.
  /// Maps contain keys: {windowId, windowTitle, x, y, width, height,
  /// isMinimized, isVisible}.
  @override
  Future<List<Map<String, dynamic>>> getVisibleWindows() async {
    final List<dynamic>? windows = await _invokeSafely<List<dynamic>>(
      'getVisibleWindows',
    );
    if (windows == null) return [];
    return windows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Shows the constraint window (WS_EX_TOOLWINDOW, always-on-top).
  /// [args] must contain keys: x, y, width, height.
  @override
  Future<void> showConstraintWindow(Map<String, dynamic> args) async {
    await _invokeSafely('showConstraintWindow', args);
  }

  /// Hides the constraint window.
  @override
  Future<void> hideConstraintWindow() async {
    await _invokeSafely('hideConstraintWindow');
  }

  /// Registers a native callback for constraint window bounds changes
  /// (WM_SIZING / WM_MOVING). Uses EventChannel
  /// 'com.breakmate.desktop/constraintWindowBounds'.
  @override
  void registerConstraintWindowBoundsCallback(
    void Function(Map<String, dynamic>) cb,
  ) {
    // TODO: Wire Windows constraint-window bounds events when the
    // native constraint window is promoted beyond the macOS-only path.
  }

  /// Shows the PiP companion window.
  @override
  Future<void> showPipWindow(Map<String, dynamic> args) async {
    await _invokeSafely('showPipWindow', args);
  }

  /// Hides the PiP companion window.
  @override
  Future<void> hidePipWindow() async {
    await _invokeSafely('hidePipWindow');
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
