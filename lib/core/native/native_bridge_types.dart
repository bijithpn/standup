import 'dart:ui';

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
  final String? pipBackgroundStyle;
  final double? pipOpacity;
  final bool? pipDraggableClickable;
  final String? companionToyType;
  final String? companionTreatType;
  final String? previewBackground;

  /// The companion's full appearance as JSON, so the overlay engine can render
  /// the exact breed, palette, and seed the user picked rather than falling
  /// back to the stock species behind [themeId].
  final String? avatarDefinitionJson;

  /// Which renderer the overlay should use: `blob` or `artwork`.
  final String? renderMode;

  /// Whether the companion stays on screen outside of breaks.
  final bool? keepOnScreen;

  /// Which interactions the overlay may offer when the pointer is over it.
  ///
  /// The overlay runs in its own engine and cannot read settings, so the only
  /// way it knows a user has switched one of these off is for it to travel in
  /// the payload.
  final bool? pettingEnabled;
  final bool? playEnabled;
  final bool? treatEnabled;

  /// How the companion looks at the pointer and animates on its own. These
  /// travel in the payload for the same reason as the interactions above.
  final bool? gazeEnabled;
  final double? gazeSensitivity;
  final bool? idleAnimation;
  final bool? reactionsEnabled;
  final bool? reducedMotion;

  /// Master animation switch (the app-wide "enable animations" preference).
  final bool? animationsEnabled;

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
    this.pipBackgroundStyle,
    this.pipOpacity,
    this.pipDraggableClickable,
    this.companionToyType,
    this.companionTreatType,
    this.previewBackground,
    this.avatarDefinitionJson,
    this.renderMode,
    this.keepOnScreen,
    this.pettingEnabled,
    this.playEnabled,
    this.treatEnabled,
    this.gazeEnabled,
    this.gazeSensitivity,
    this.idleAnimation,
    this.reactionsEnabled,
    this.reducedMotion,
    this.animationsEnabled,
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
    if (avatarDefinitionJson != null) {
      map['avatarDefinitionJson'] = avatarDefinitionJson;
    }
    if (renderMode != null) map['renderMode'] = renderMode;
    if (keepOnScreen != null) map['keepOnScreen'] = keepOnScreen;
    if (pettingEnabled != null) map['pettingEnabled'] = pettingEnabled;
    if (playEnabled != null) map['playEnabled'] = playEnabled;
    if (treatEnabled != null) map['treatEnabled'] = treatEnabled;
    if (gazeEnabled != null) map['gazeEnabled'] = gazeEnabled;
    if (gazeSensitivity != null) map['gazeSensitivity'] = gazeSensitivity;
    if (idleAnimation != null) map['idleAnimation'] = idleAnimation;
    if (reactionsEnabled != null) map['reactionsEnabled'] = reactionsEnabled;
    if (reducedMotion != null) map['reducedMotion'] = reducedMotion;
    if (animationsEnabled != null) map['animationsEnabled'] = animationsEnabled;
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
      pipBackgroundStyle: map['pipBackgroundStyle'] as String?,
      pipOpacity: (map['pipOpacity'] as num?)?.toDouble(),
      pipDraggableClickable: map['pipDraggableClickable'] as bool?,
      companionToyType: map['companionToyType'] as String?,
      companionTreatType: map['companionTreatType'] as String?,
      previewBackground: map['previewBackground'] as String?,
      avatarDefinitionJson: map['avatarDefinitionJson'] as String?,
      renderMode: map['renderMode'] as String?,
      keepOnScreen: map['keepOnScreen'] as bool?,
      pettingEnabled: map['pettingEnabled'] as bool?,
      playEnabled: map['playEnabled'] as bool?,
      treatEnabled: map['treatEnabled'] as bool?,
      gazeEnabled: map['gazeEnabled'] as bool?,
      gazeSensitivity: (map['gazeSensitivity'] as num?)?.toDouble(),
      idleAnimation: map['idleAnimation'] as bool?,
      reactionsEnabled: map['reactionsEnabled'] as bool?,
      reducedMotion: map['reducedMotion'] as bool?,
      animationsEnabled: map['animationsEnabled'] as bool?,
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
}
