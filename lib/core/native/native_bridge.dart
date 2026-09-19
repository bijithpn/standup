import 'dart:io';
import 'dart:ui';
import 'package:breakmate/core/display/models/display_info.dart';
import 'package:breakmate/core/native/macos_bridge.dart';
import 'package:breakmate/core/native/windows_bridge.dart';

class OverlayArgs {
  final Map<String, dynamic>? args;

  const OverlayArgs({this.args});

  Map<String, dynamic>? toMap() => args;
}

class OverlayData {
  final Map<String, dynamic> data;

  const OverlayData(this.data);

  Map<String, dynamic> toMap() => data;
}

class CompanionArgs {
  final Map<String, dynamic> args;

  const CompanionArgs(this.args);

  Map<String, dynamic> toMap() => args;
}

class ConstraintWindowArgs {
  final double x;
  final double y;
  final double width;
  final double height;

  const ConstraintWindowArgs({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toMap() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory ConstraintWindowArgs.fromMap(Map<String, dynamic> map) {
    return ConstraintWindowArgs(
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PipWindowArgs {
  final double? x;
  final double? y;
  final double? width;
  final double? height;
  final String themeId;
  final String petName;
  final double scale;
  final bool? clickThrough;
  final bool? followMouse;
  final bool? wanderingEnabled;
  final bool? isLowPowerMode;
  final String? pipBackgroundStyle;
  final double? pipOpacity;
  final bool? pipDraggableClickable;
  final String? companionToyType;
  final String? companionTreatType;
  final String? previewBackground;

  const PipWindowArgs({
    this.x,
    this.y,
    this.width,
    this.height,
    required this.themeId,
    required this.petName,
    required this.scale,
    this.clickThrough,
    this.followMouse,
    this.wanderingEnabled,
    this.isLowPowerMode,
    this.pipBackgroundStyle,
    this.pipOpacity,
    this.pipDraggableClickable,
    this.companionToyType,
    this.companionTreatType,
    this.previewBackground,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'themeId': themeId,
      'petName': petName,
      'scale': scale,
    };
    if (x != null) map['x'] = x;
    if (y != null) map['y'] = y;
    if (width != null) map['width'] = width;
    if (height != null) map['height'] = height;
    if (clickThrough != null) map['clickThrough'] = clickThrough;
    if (followMouse != null) map['followMouse'] = followMouse;
    if (wanderingEnabled != null) map['wanderingEnabled'] = wanderingEnabled;
    if (isLowPowerMode != null) map['isLowPowerMode'] = isLowPowerMode;
    if (pipBackgroundStyle != null) {
      map['pipBackgroundStyle'] = pipBackgroundStyle;
    }
    if (pipOpacity != null) {
      map['pipOpacity'] = pipOpacity;
    }
    if (pipDraggableClickable != null) {
      map['pipDraggableClickable'] = pipDraggableClickable;
    }
    if (companionToyType != null) {
      map['companionToyType'] = companionToyType;
    }
    if (companionTreatType != null) {
      map['companionTreatType'] = companionTreatType;
    }
    if (previewBackground != null) map['previewBackground'] = previewBackground;
    return map;
  }

  factory PipWindowArgs.fromMap(Map<String, dynamic> map) {
    return PipWindowArgs(
      x: (map['x'] as num?)?.toDouble(),
      y: (map['y'] as num?)?.toDouble(),
      width: (map['width'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
      themeId: map['themeId'] as String? ?? 'black_cat',
      petName: map['petName'] as String? ?? 'Mochi',
      scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
      clickThrough: map['clickThrough'] as bool?,
      followMouse: map['followMouse'] as bool?,
      wanderingEnabled: map['wanderingEnabled'] as bool?,
      isLowPowerMode: map['isLowPowerMode'] as bool?,
      pipBackgroundStyle: map['pipBackgroundStyle'] as String?,
      pipOpacity: (map['pipOpacity'] as num?)?.toDouble(),
      pipDraggableClickable: map['pipDraggableClickable'] as bool?,
      companionToyType: map['companionToyType'] as String?,
      companionTreatType: map['companionTreatType'] as String?,
      previewBackground: map['previewBackground'] as String?,
    );
  }
}

class NativeDisplayInfo {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final double dpiScale;
  final bool isPrimary;

  const NativeDisplayInfo({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.dpiScale,
    required this.isPrimary,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'dpiScale': dpiScale,
    'isPrimary': isPrimary,
  };

  factory NativeDisplayInfo.fromMap(Map<String, dynamic> map) {
    return NativeDisplayInfo(
      id: map['id']?.toString() ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
      dpiScale: (map['dpiScale'] as num?)?.toDouble() ?? 1.0,
      isPrimary: map['isPrimary'] as bool? ?? false,
    );
  }
}

class WindowInfo {
  final String windowId;
  final String windowTitle;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool isMinimized;
  final bool isVisible;

  const WindowInfo({
    required this.windowId,
    required this.windowTitle,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.isMinimized,
    required this.isVisible,
  });

  Map<String, dynamic> toMap() => {
    'windowId': windowId,
    'windowTitle': windowTitle,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'isMinimized': isMinimized,
    'isVisible': isVisible,
  };

  factory WindowInfo.fromMap(Map<String, dynamic> map) {
    return WindowInfo(
      windowId: map['windowId']?.toString() ?? '',
      windowTitle: map['windowTitle'] as String? ?? '',
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
      isMinimized: map['isMinimized'] as bool? ?? false,
      isVisible: map['isVisible'] as bool? ?? false,
    );
  }
}

/// Platform boundary for desktop features implemented outside Flutter.
/// The Dart layer still receives several platform payloads as maps because
/// MethodChannel is the compatibility boundary between the Flutter engines and
abstract class NativeBridgePlatform {
  Future<void> showOverlay([OverlayArgs? args]);
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
  Future<void> updateOverlayData(OverlayData data);
  Future<void> showCompanion(CompanionArgs args);
  Future<void> hideCompanion();
  Future<void> setCompanionClickThrough(bool ignore);
  Future<void> updateCompanionScale(double scale);
  Future<void> updateCompanionTheme(String themeId);
  Future<void> updateCompanionName(String petName);
  Future<void> triggerCompanionState(String stateName);
  Future<void> setCompanionWandering(bool enabled);
  Future<void> setCompanionFollowMouse(bool enabled);

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

  Future<List<NativeDisplayInfo>> enumerateDisplays();

  void registerDisplayChangeCallback(void Function(List<NativeDisplayInfo>) cb);

  Future<Offset> getCursorPosition();

  Future<List<WindowInfo>> getVisibleWindows();

  Future<void> showConstraintWindow(ConstraintWindowArgs args);

  Future<void> hideConstraintWindow();

  void registerConstraintWindowBoundsCallback(
    void Function(ConstraintWindowArgs) callback,
  );

  Future<void> showPipWindow(PipWindowArgs args);

  Future<void> hidePipWindow();

  Future<void> openAvatarEditor(String editorUrl);
}

class FallbackBridge implements NativeBridgePlatform {
  const FallbackBridge();

  @override
  Future<void> showOverlay([OverlayArgs? args]) async {}

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
  Future<void> updateOverlayData(OverlayData data) async {}

  @override
  Future<void> showCompanion(CompanionArgs args) async {}

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
  Future<List<NativeDisplayInfo>> enumerateDisplays() async => [];

  @override
  void registerDisplayChangeCallback(
    void Function(List<NativeDisplayInfo>) cb,
  ) {}

  @override
  Future<Offset> getCursorPosition() async => Offset.zero;

  @override
  Future<List<WindowInfo>> getVisibleWindows() async => [];

  @override
  Future<void> showConstraintWindow(ConstraintWindowArgs args) async {}

  @override
  Future<void> hideConstraintWindow() async {}

  @override
  void registerConstraintWindowBoundsCallback(
    void Function(ConstraintWindowArgs) cb,
  ) {}

  @override
  Future<void> showPipWindow(PipWindowArgs args) async {}

  @override
  Future<void> hidePipWindow() async {}

  @override
  Future<void> openAvatarEditor(String editorUrl) async {}
}

class NativeBridge {
  static final NativeBridgePlatform _platform = _getPlatformBridge();

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

  static Future<void> openAvatarEditor(String editorUrl) =>
      _platform.openAvatarEditor(editorUrl);
}
