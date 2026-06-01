import 'dart:io';
import 'package:breakmate/core/native/macos_bridge.dart';
import 'package:breakmate/core/native/windows_bridge.dart';

/// Common interface for the native native bridge functions across platforms
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

  // Calendar Support
  Future<bool> requestCalendarPermissions();
  Future<bool> hasCalendarPermissions();
  Future<void> openCalendarSettings();
  Future<List<Map<String, dynamic>>> getUpcomingCalendarEvents(int windowMinutes);
}

/// A fallback/no-op implementation for unsupported platforms
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
  Future<void> openCalendarSettings() async {}

  @override
  Future<List<Map<String, dynamic>>> getUpcomingCalendarEvents(
    int windowMinutes,
  ) async =>
      [];
}

/// Unified entry point to call native bridge features.
/// Automatically detects platform and delegates to the appropriate bridge.
class NativeBridge {
  static final NativeBridgePlatform _platform = _getPlatformBridge();

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
  static Future<void> openCalendarSettings() =>
      _platform.openCalendarSettings();
  static Future<List<Map<String, dynamic>>> getUpcomingCalendarEvents(
    int windowMinutes,
  ) =>
      _platform.getUpcomingCalendarEvents(windowMinutes);
}
