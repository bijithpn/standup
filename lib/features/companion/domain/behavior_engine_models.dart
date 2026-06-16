import 'dart:ui';
import 'pet_state_machine.dart';

enum PetMode { freeRoam, constrained, singleDisplay }

enum ThrowableLifecycle { flying, stationary, beingFetched, disposed }

typedef PhysicsEntityId = int;

class DisplayBounds {
  final String id;

  final Rect rect;

  final double dpiScale;

  final bool isPrimary;

  const DisplayBounds({
    required this.id,
    required this.rect,
    required this.dpiScale,
    required this.isPrimary,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayBounds &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          rect == other.rect &&
          dpiScale == other.dpiScale &&
          isPrimary == other.isPrimary;

  @override
  int get hashCode => Object.hash(id, rect, dpiScale, isPrimary);

  @override
  String toString() =>
      'DisplayBounds(id: $id, rect: $rect, dpiScale: $dpiScale, isPrimary: $isPrimary)';
}

class WindowInfo {
  final int windowId;

  final String? appBundleId;

  final String? windowTitle;

  final Rect bounds;

  final bool isMinimized;

  final bool isVisible;

  const WindowInfo({
    required this.windowId,
    this.appBundleId,
    this.windowTitle,
    required this.bounds,
    required this.isMinimized,
    required this.isVisible,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindowInfo &&
          runtimeType == other.runtimeType &&
          windowId == other.windowId &&
          appBundleId == other.appBundleId &&
          windowTitle == other.windowTitle &&
          bounds == other.bounds &&
          isMinimized == other.isMinimized &&
          isVisible == other.isVisible;

  @override
  int get hashCode => Object.hash(
    windowId,
    appBundleId,
    windowTitle,
    bounds,
    isMinimized,
    isVisible,
  );

  @override
  String toString() =>
      'WindowInfo(windowId: $windowId, title: $windowTitle, bounds: $bounds, '
      'isMinimized: $isMinimized, isVisible: $isVisible)';
}

class PhysicsEntityState {
  final double x;

  final double y;

  final double vx;

  final double vy;

  final double width;

  final double height;

  final bool isAirborne;

  final bool isStationary;

  final int stationaryTicks;

  const PhysicsEntityState({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.width,
    required this.height,
    required this.isAirborne,
    required this.isStationary,
    required this.stationaryTicks,
  });

  PhysicsEntityState copyWith({
    double? x,
    double? y,
    double? vx,
    double? vy,
    double? width,
    double? height,
    bool? isAirborne,
    bool? isStationary,
    int? stationaryTicks,
  }) {
    return PhysicsEntityState(
      x: x ?? this.x,
      y: y ?? this.y,
      vx: vx ?? this.vx,
      vy: vy ?? this.vy,
      width: width ?? this.width,
      height: height ?? this.height,
      isAirborne: isAirborne ?? this.isAirborne,
      isStationary: isStationary ?? this.isStationary,
      stationaryTicks: stationaryTicks ?? this.stationaryTicks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhysicsEntityState &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          vx == other.vx &&
          vy == other.vy &&
          width == other.width &&
          height == other.height &&
          isAirborne == other.isAirborne &&
          isStationary == other.isStationary &&
          stationaryTicks == other.stationaryTicks;

  @override
  int get hashCode => Object.hash(
    x,
    y,
    vx,
    vy,
    width,
    height,
    isAirborne,
    isStationary,
    stationaryTicks,
  );

  @override
  String toString() =>
      'PhysicsEntityState(x: $x, y: $y, vx: $vx, vy: $vy, '
      'w: $width, h: $height, airborne: $isAirborne, stationary: $isStationary, '
      'stationaryTicks: $stationaryTicks)';
}

class ThrowableObjectState {
  final int id;

  final int spawnPriority;

  final Offset spawnOrigin;

  final PhysicsEntityId physicsId;

  final ThrowableLifecycle lifecycle;

  final int stationaryTickCount;

  final DateTime? stationaryAt;

  final DateTime? unreachableSince;

  final String kind;

  final Offset position;

  const ThrowableObjectState({
    required this.id,
    required this.spawnPriority,
    required this.spawnOrigin,
    required this.physicsId,
    required this.lifecycle,
    required this.stationaryTickCount,
    this.stationaryAt,
    this.unreachableSince,
    this.kind = 'ball',
    this.position = Offset.zero,
  });

  ThrowableObjectState copyWith({
    int? id,
    int? spawnPriority,
    Offset? spawnOrigin,
    PhysicsEntityId? physicsId,
    ThrowableLifecycle? lifecycle,
    int? stationaryTickCount,
    DateTime? stationaryAt,
    DateTime? unreachableSince,
    String? kind,
    Offset? position,
  }) {
    return ThrowableObjectState(
      id: id ?? this.id,
      spawnPriority: spawnPriority ?? this.spawnPriority,
      spawnOrigin: spawnOrigin ?? this.spawnOrigin,
      physicsId: physicsId ?? this.physicsId,
      lifecycle: lifecycle ?? this.lifecycle,
      stationaryTickCount: stationaryTickCount ?? this.stationaryTickCount,
      stationaryAt: stationaryAt ?? this.stationaryAt,
      unreachableSince: unreachableSince ?? this.unreachableSince,
      kind: kind ?? this.kind,
      position: position ?? this.position,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThrowableObjectState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          spawnPriority == other.spawnPriority &&
          spawnOrigin == other.spawnOrigin &&
          physicsId == other.physicsId &&
          lifecycle == other.lifecycle &&
          stationaryTickCount == other.stationaryTickCount &&
          stationaryAt == other.stationaryAt &&
          unreachableSince == other.unreachableSince &&
          kind == other.kind &&
          position == other.position;

  @override
  int get hashCode => Object.hash(
    id,
    spawnPriority,
    spawnOrigin,
    physicsId,
    lifecycle,
    stationaryTickCount,
    stationaryAt,
    unreachableSince,
    kind,
    position,
  );

  @override
  String toString() =>
      'ThrowableObjectState(id: $id, priority: $spawnPriority, '
      'kind: $kind, lifecycle: $lifecycle, stationaryTickCount: $stationaryTickCount)';
}

class PetConfigV2 {
  final PetMode mode;

  final String? pinnedDisplayId;

  final Rect constraintWindowBounds;

  final Offset lastAnchorPoint;

  final String themeId;

  final String petName;

  final double scale;

  const PetConfigV2({
    required this.mode,
    required this.pinnedDisplayId,
    required this.constraintWindowBounds,
    required this.lastAnchorPoint,
    required this.themeId,
    required this.petName,
    required this.scale,
  });

  factory PetConfigV2.defaults() => const PetConfigV2(
    mode: PetMode.freeRoam,
    pinnedDisplayId: null,
    constraintWindowBounds: Rect.fromLTWH(100, 100, 300, 300),
    lastAnchorPoint: Offset.zero,
    themeId: 'grey_cat',
    petName: 'Mochi',
    scale: 6.0,
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': mode.name,
      'pinnedDisplayId': pinnedDisplayId,
      'constraintWindowBounds': _rectToJson(constraintWindowBounds),
      'lastAnchorPoint': _offsetToJson(lastAnchorPoint),
      'themeId': themeId,
      'petName': petName,
      'scale': scale,
    };
  }

  factory PetConfigV2.fromJson(Map<String, dynamic> json) {
    final defaults = PetConfigV2.defaults();
    return PetConfigV2(
      mode: _parsePetMode(json['mode'] as String?, defaults.mode),
      pinnedDisplayId: json['pinnedDisplayId'] as String?,
      constraintWindowBounds: _parseRect(
        json['constraintWindowBounds'],
        defaults.constraintWindowBounds,
      ),
      lastAnchorPoint: _parseOffset(
        json['lastAnchorPoint'],
        defaults.lastAnchorPoint,
      ),
      themeId: json['themeId'] as String? ?? defaults.themeId,
      petName: json['petName'] as String? ?? defaults.petName,
      scale: (json['scale'] as num?)?.toDouble() ?? defaults.scale,
    );
  }

  PetConfigV2 copyWith({
    PetMode? mode,
    Object? pinnedDisplayId = _sentinel,
    Rect? constraintWindowBounds,
    Offset? lastAnchorPoint,
    String? themeId,
    String? petName,
    double? scale,
  }) {
    return PetConfigV2(
      mode: mode ?? this.mode,
      pinnedDisplayId: pinnedDisplayId == _sentinel
          ? this.pinnedDisplayId
          : pinnedDisplayId as String?,
      constraintWindowBounds:
          constraintWindowBounds ?? this.constraintWindowBounds,
      lastAnchorPoint: lastAnchorPoint ?? this.lastAnchorPoint,
      themeId: themeId ?? this.themeId,
      petName: petName ?? this.petName,
      scale: scale ?? this.scale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetConfigV2 &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          pinnedDisplayId == other.pinnedDisplayId &&
          constraintWindowBounds == other.constraintWindowBounds &&
          lastAnchorPoint == other.lastAnchorPoint &&
          themeId == other.themeId &&
          petName == other.petName &&
          scale == other.scale;

  @override
  int get hashCode => Object.hash(
    mode,
    pinnedDisplayId,
    constraintWindowBounds,
    lastAnchorPoint,
    themeId,
    petName,
    scale,
  );

  @override
  String toString() =>
      'PetConfigV2(mode: $mode, themeId: $themeId, petName: $petName, '
      'scale: $scale, lastAnchorPoint: $lastAnchorPoint)';

  static const Object _sentinel = Object();

  static PetMode _parsePetMode(String? raw, PetMode fallback) {
    if (raw == null) return fallback;
    return PetMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => fallback,
    );
  }

  static Map<String, dynamic> _rectToJson(Rect rect) => <String, dynamic>{
    'left': rect.left,
    'top': rect.top,
    'width': rect.width,
    'height': rect.height,
  };

  static Rect _parseRect(dynamic raw, Rect fallback) {
    if (raw is! Map) return fallback;
    final map = raw as Map<String, dynamic>;
    final left = (map['left'] as num?)?.toDouble();
    final top = (map['top'] as num?)?.toDouble();
    final width = (map['width'] as num?)?.toDouble();
    final height = (map['height'] as num?)?.toDouble();
    if (left == null || top == null || width == null || height == null) {
      return fallback;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  static Map<String, dynamic> _offsetToJson(Offset offset) => <String, dynamic>{
    'dx': offset.dx,
    'dy': offset.dy,
  };

  static Offset _parseOffset(dynamic raw, Offset fallback) {
    if (raw is! Map) return fallback;
    final map = raw as Map<String, dynamic>;
    final dx = (map['dx'] as num?)?.toDouble();
    final dy = (map['dy'] as num?)?.toDouble();
    if (dx == null || dy == null) return fallback;
    return Offset(dx, dy);
  }
}

class StateTransitionLog {
  final PetState previousState;

  final PetState newState;

  final DateTime utcTimestamp;

  const StateTransitionLog({
    required this.previousState,
    required this.newState,
    required this.utcTimestamp,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'previousState': previousState.name,
    'newState': newState.name,
    'utcTimestamp': utcTimestamp.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StateTransitionLog &&
          runtimeType == other.runtimeType &&
          previousState == other.previousState &&
          newState == other.newState &&
          utcTimestamp == other.utcTimestamp;

  @override
  int get hashCode => Object.hash(previousState, newState, utcTimestamp);

  @override
  String toString() =>
      'StateTransitionLog($previousState → $newState @ $utcTimestamp)';
}
