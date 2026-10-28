import 'dart:io';
import 'dart:ui';
import 'package:breakmate/core/display/models/display_info.dart';
import 'package:breakmate/core/native/macos_bridge.dart';
import 'package:breakmate/core/native/linux_bridge.dart';
import 'package:breakmate/core/native/native_bridge_types.dart';
import 'package:breakmate/core/native/windows_bridge.dart';

export 'package:breakmate/core/native/native_bridge_types.dart';

class NativeBridge {
  static final NativeBridgePlatform _platform = _getPlatformBridge();

  static NativeBridgePlatform get instance => _platform;

  static NativeBridgePlatform _getPlatformBridge() {
    if (Platform.isMacOS) {
      return MacOSBridge();
    } else if (Platform.isWindows) {
      return WindowsBridge();
    } else if (Platform.isLinux) {
      return LinuxBridge();
    } else {
      return const FallbackBridge();
    }
  }

  static Future<void> showOverlay([OverlayArgs? args]) =>
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
  static Future<void> updateOverlayData(OverlayData data) =>
      _platform.updateOverlayData(data);
  static Future<void> showCompanion(CompanionArgs args) =>
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

  static Future<List<DisplayInfo>> enumerateDisplays() async {
    final nativeDisplays = await _platform.enumerateDisplays();
    return nativeDisplays.map((nativeDisplay) {
      return DisplayInfo(
        id: nativeDisplay.id,
        isPrimary: nativeDisplay.isPrimary,
        width: nativeDisplay.width,
        height: nativeDisplay.height,
        pixelRatio: nativeDisplay.dpiScale,
        bounds: Rect.fromLTWH(
          nativeDisplay.x,
          nativeDisplay.y,
          nativeDisplay.width,
          nativeDisplay.height,
        ),
        workArea: Rect.fromLTWH(
          nativeDisplay.x,
          nativeDisplay.y,
          nativeDisplay.width,
          nativeDisplay.height,
        ),
        position: Offset(nativeDisplay.x, nativeDisplay.y),
        refreshRate: 60.0, // Default value since not available in native bridge
      );
    }).toList();
  }

  static void registerDisplayChangeCallback(
    void Function(List<DisplayInfo>) cb,
  ) {
    _platform.registerDisplayChangeCallback((
      List<NativeDisplayInfo> nativeDisplays,
    ) {
      final displays = nativeDisplays.map((nativeDisplay) {
        return DisplayInfo(
          id: nativeDisplay.id,
          isPrimary: nativeDisplay.isPrimary,
          width: nativeDisplay.width,
          height: nativeDisplay.height,
          pixelRatio: nativeDisplay.dpiScale,
          bounds: Rect.fromLTWH(
            nativeDisplay.x,
            nativeDisplay.y,
            nativeDisplay.width,
            nativeDisplay.height,
          ),
          workArea: Rect.fromLTWH(
            nativeDisplay.x,
            nativeDisplay.y,
            nativeDisplay.width,
            nativeDisplay.height,
          ),
          position: Offset(nativeDisplay.x, nativeDisplay.y),
          refreshRate:
              60.0, // Default value since not available in native bridge
        );
      }).toList();
      cb(displays);
    });
  }

  static Future<Offset> getCursorPosition() => _platform.getCursorPosition();

  static Future<List<WindowInfo>> getVisibleWindows() =>
      _platform.getVisibleWindows();

  static Future<void> showConstraintWindow(ConstraintWindowArgs args) =>
      _platform.showConstraintWindow(args);

  static Future<void> hideConstraintWindow() =>
      _platform.hideConstraintWindow();

  static void registerConstraintWindowBoundsCallback(
    void Function(ConstraintWindowArgs) cb,
  ) => _platform.registerConstraintWindowBoundsCallback(cb);

  static Future<void> showPipWindow(PipWindowArgs args) =>
      _platform.showPipWindow(args);

  static Future<void> hidePipWindow() => _platform.hidePipWindow();
}
