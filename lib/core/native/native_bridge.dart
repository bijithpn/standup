import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:breakmate/core/native/macos_bridge.dart';
import 'package:breakmate/core/native/windows_bridge.dart';

/// Platform boundary for desktop features implemented outside Flutter.
///
/// The Dart layer still receives several platform payloads as maps because
/// MethodChannel is the compatibility boundary between the Flutter engines and
/// native runners.
// TODO: Replace the remaining raw map payloads with typed bridge
// models before adding new native channels, so validation stays consistent
// across macOS, Windows, and tests.
abstract class NativeBridgePlatform {
  Future<void> showOverlay([Map<String, dynamic>? args]);
  Future<void> hideOverlay({bool restoreMainWindow = true});
  Future<void> skipBreak();
  Future<void> setVisualEffect(String material);
  Future<void> focusApp();
  Future<void> setWindowLevel(String level);
  Future<void> setPresentationOptions({
    required bool hideDock,
    required bool hideMenu,
  });
  Future<double> getIdleTime();
  Future<String> getAppearance();
  Future<void> setIgnoreMouseEvents(bool ignore);
  Future<void> updateOverlayData(Map<String, dynamic> data);
  Future<void> showCompanion(Map<String, dynamic> args);
  Future<void> hideCompanion();
  Future<void> setCompanionClickThrough(bool ignore);
  Future<void> updateCompanionScale(double scale);
  Future<void> updateCompanionTheme(String themeId);
  Future<void> updateCompanionName(String petName);
  Future<void> triggerCompanionState(String stateName);
  Future<void> setCompanionWandering(bool enabled);
  Future<void> setCompanionFollowMouse(bool enabled);

  // Calendar support.
  Future<bool> requestCalendarPermissions();
  Future<bool> hasCalendarPermissions();
  Future<String> getCalendarPermissionStatus();
  Future<void> openCalendarSettings();
  Future<List<Map<String, dynamic>>> getUpcomingCalendarEvents(
    int windowMinutes,
  );
  Future<List<Map<String, dynamic>>> getCalendars();
  Future<List<Map<String, dynamic>>> getEvents(
    int startMs,
    int endMs,
    List<String>? calendarIds,
  );

  // Display management.
  /// Returns a list of connected displays as maps with keys:
  /// {id, x, y, width, height, dpiScale, isPrimary}
  Future<List<Map<String, dynamic>>> enumerateDisplays();

  /// Registers a callback that is invoked when displays change (connect /
  /// disconnect / resolution change). The callback receives the updated list
  /// of display maps using the same schema as [enumerateDisplays].
  void registerDisplayChangeCallback(
    void Function(List<Map<String, dynamic>>) cb,
  );

  // Cursor position in global screen coordinates.
  /// Returns the current cursor position in global screen coordinates.
  Future<Offset> getCursorPosition();

  // Window enumeration.
  /// Returns the list of currently visible, non-minimized application windows
  /// as maps with keys: {windowId, appBundleId, windowTitle, x, y, width,
  /// height, isMinimized, isVisible}
  Future<List<Map<String, dynamic>>> getVisibleWindows();

  // Constraint window.
  /// Shows the constraint window using the provided [args] map.
  /// Expected keys: x, y, width, height.
  Future<void> showConstraintWindow(Map<String, dynamic> args);

  /// Hides the constraint window.
  Future<void> hideConstraintWindow();

  /// Registers a callback invoked when the constraint window is moved or
  /// resized. The callback receives a map with keys: x, y, width, height.
  void registerConstraintWindowBoundsCallback(
    void Function(Map<String, dynamic>) cb,
  );

  // PiP companion window.
  /// Shows the PiP companion window.
  /// Expected keys: x, y, width, height, themeId, petName, scale.
  Future<void> showPipWindow(Map<String, dynamic> args);

  /// Hides the PiP companion window.
  Future<void> hidePipWindow();
}

/// A fallback/no-op implementation for unsupported platforms.
///
/// All new PAL methods return safe defaults without throwing so that
/// upper-layer subsystems can be exercised on unsupported platforms in tests.
class FallbackBridge implements NativeBridgePlatform {
  const FallbackBridge();

  @override
  Future<void> showOverlay([Map<String, dynamic>? args]) async {}

  @override
  Future<void> hideOverlay({bool restoreMainWindow = true}) async {}

  @override
  Future<void> skipBreak() async {}

  @override
  Future<void> setVisualEffect(String material) async {}

  @override
  Future<void> focusApp() async {}

  @override
  Future<void> setWindowLevel(String level) async {}

  @override
  Future<void> setPresentationOptions({
    required bool hideDock,
    required bool hideMenu,
  }) async {}

  @override
  Future<double> getIdleTime() async => 0.0;

  @override
  Future<String> getAppearance() async => 'light';

  @override
  Future<void> setIgnoreMouseEvents(bool ignore) async {}

  @override
  Future<void> updateOverlayData(Map<String, dynamic> data) async {}

  @override
  Future<void> showCompanion(Map<String, dynamic> args) async {}

  @override
  Future<void> hideCompanion() async {}

  @override
  Future<void> setCompanionClickThrough(bool ignore) async {}

  @override
  Future<void> updateCompanionScale(double scale) async {}

  @override
  Future<void> updateCompanionTheme(String themeId) async {}

  @override
  Future<void> updateCompanionName(String petName) async {}

  @override
  Future<void> triggerCompanionState(String stateName) async {}

  @override
  Future<void> setCompanionWandering(bool enabled) async {}

  @override
  Future<void> setCompanionFollowMouse(bool enabled) async {}

  @override
  Future<bool> requestCalendarPermissions() async => false;

  @override
  Future<bool> hasCalendarPermissions() async => false;

  @override
  Future<String> getCalendarPermissionStatus() async => 'denied';

  @override
  Future<void> openCalendarSettings() async {}

  @override
  Future<List<Map<String, dynamic>>> getUpcomingCalendarEvents(
    int windowMinutes,
  ) async => [];

  @override
  Future<List<Map<String, dynamic>>> getCalendars() async => [];

  @override
  Future<List<Map<String, dynamic>>> getEvents(
    int startMs,
    int endMs,
    List<String>? calendarIds,
  ) async => [];

  @override
  Future<List<Map<String, dynamic>>> enumerateDisplays() async => [];

  @override
  void registerDisplayChangeCallback(
    void Function(List<Map<String, dynamic>>) cb,
  ) {
    // No-op: no displays to report on unsupported platforms.
  }

  @override
  Future<Offset> getCursorPosition() async => Offset.zero;

  @override
  Future<List<Map<String, dynamic>>> getVisibleWindows() async => [];

  @override
  Future<void> showConstraintWindow(Map<String, dynamic> args) async {}

  @override
  Future<void> hideConstraintWindow() async {}

  @override
  void registerConstraintWindowBoundsCallback(
    void Function(Map<String, dynamic>) cb,
  ) {
    // No-op: constraint window is never shown on unsupported platforms.
  }

  @override
  Future<void> showPipWindow(Map<String, dynamic> args) async {}

  @override
  Future<void> hidePipWindow() async {}
}

/// Unified entry point to call native bridge features.
/// Automatically detects platform and delegates to the appropriate bridge.
class NativeBridge {
  static final NativeBridgePlatform _platform = _getPlatformBridge();

  /// The underlying platform bridge instance.
  ///
  /// Exposed so that service classes (e.g., [DisplayManager]) can be
  /// constructed with the singleton bridge by default while still accepting
  /// an injected [NativeBridgePlatform] for testing.
  static NativeBridgePlatform get instance => _platform;

  static NativeBridgePlatform _getPlatformBridge() {
    if (Platform.isMacOS) {
      return MacOSBridge();
    } else if (Platform.isWindows) {
      return WindowsBridge();
    } else {
      return const FallbackBridge();
    }
  }

  static Future<void> showOverlay([Map<String, dynamic>? args]) =>
      _platform.showOverlay(args);
  static Future<void> hideOverlay({bool restoreMainWindow = true}) =>
      _platform.hideOverlay(restoreMainWindow: restoreMainWindow);
  static Future<void> skipBreak() => _platform.skipBreak();
  static Future<void> setVisualEffect(String material) =>
      _platform.setVisualEffect(material);
  static Future<void> focusApp() => _platform.focusApp();
  static Future<void> setWindowLevel(String level) =>
      _platform.setWindowLevel(level);
  static Future<void> setPresentationOptions({
    required bool hideDock,
    required bool hideMenu,
  }) =>
      _platform.setPresentationOptions(hideDock: hideDock, hideMenu: hideMenu);
  static Future<double> getIdleTime() => _platform.getIdleTime();
  static Future<String> getAppearance() => _platform.getAppearance();
  static Future<void> setIgnoreMouseEvents(bool ignore) =>
      _platform.setIgnoreMouseEvents(ignore);
  static Future<void> updateOverlayData(Map<String, dynamic> data) =>
      _platform.updateOverlayData(data);
  static Future<void> showCompanion(Map<String, dynamic> args) =>
      _platform.showCompanion(args);
  static Future<void> hideCompanion() => _platform.hideCompanion();
  static Future<void> setCompanionClickThrough(bool ignore) =>
      _platform.setCompanionClickThrough(ignore);
  static Future<void> updateCompanionScale(double scale) =>
      _platform.updateCompanionScale(scale);
  static Future<void> updateCompanionTheme(String themeId) =>
      _platform.updateCompanionTheme(themeId);
  static Future<void> updateCompanionName(String petName) =>
      _platform.updateCompanionName(petName);
  static Future<void> triggerCompanionState(String stateName) =>
      _platform.triggerCompanionState(stateName);
  static Future<void> setCompanionWandering(bool enabled) =>
      _platform.setCompanionWandering(enabled);
  static Future<void> setCompanionFollowMouse(bool enabled) =>
      _platform.setCompanionFollowMouse(enabled);

  static Future<bool> requestCalendarPermissions() =>
      _platform.requestCalendarPermissions();
  static Future<bool> hasCalendarPermissions() =>
      _platform.hasCalendarPermissions();
  static Future<String> getCalendarPermissionStatus() =>
      _platform.getCalendarPermissionStatus();
  static Future<void> openCalendarSettings() =>
      _platform.openCalendarSettings();
  static Future<List<Map<String, dynamic>>> getUpcomingCalendarEvents(
    int windowMinutes,
  ) => _platform.getUpcomingCalendarEvents(windowMinutes);
  static Future<List<Map<String, dynamic>>> getCalendars() =>
      _platform.getCalendars();
  static Future<List<Map<String, dynamic>>> getEvents(
    int startMs,
    int endMs,
    List<String>? calendarIds,
  ) => _platform.getEvents(startMs, endMs, calendarIds);

  // --- New PAL forwarding methods ---

  static Future<List<Map<String, dynamic>>> enumerateDisplays() =>
      _platform.enumerateDisplays();

  static void registerDisplayChangeCallback(
    void Function(List<Map<String, dynamic>>) cb,
  ) => _platform.registerDisplayChangeCallback(cb);

  static Future<Offset> getCursorPosition() => _platform.getCursorPosition();

  static Future<List<Map<String, dynamic>>> getVisibleWindows() =>
      _platform.getVisibleWindows();

  static Future<void> showConstraintWindow(Map<String, dynamic> args) =>
      _platform.showConstraintWindow(args);

  static Future<void> hideConstraintWindow() =>
      _platform.hideConstraintWindow();

  static void registerConstraintWindowBoundsCallback(
    void Function(Map<String, dynamic>) cb,
  ) => _platform.registerConstraintWindowBoundsCallback(cb);

  // --- PiP window ---

  static Future<void> showPipWindow(Map<String, dynamic> args) =>
      _platform.showPipWindow(args);

  static Future<void> hidePipWindow() => _platform.hidePipWindow();
}
