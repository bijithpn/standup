import 'dart:ui';
import 'pet_state_machine.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Operating mode that governs how much of the screen the pet may traverse.
enum PetMode {
  /// Pet may roam freely across all connected displays.
  freeRoam,

  /// Pet is confined to a user-defined [ConstraintWindow].
  constrained,

  /// Pet is restricted to a single pinned display.
  singleDisplay,
}

/// Lifecycle state of a [ThrowableObjectState].
enum ThrowableLifecycle {
  /// Object is in the air, physics active.
  flying,

  /// Object has come to rest on a surface.
  stationary,

  /// Pet has picked it up and is carrying it back to the throw origin.
  beingFetched,

  /// Object has been returned or timed out; pending removal.
  disposed,
}

// ---------------------------------------------------------------------------
// Type aliases
// ---------------------------------------------------------------------------

/// Opaque identifier for a physics-simulated entity.
///
/// Using a typedef over `int` keeps the domain model readable and allows the
/// physics layer to change its internal key type without touching callers.
typedef PhysicsEntityId = int;

// ---------------------------------------------------------------------------
// DisplayBounds
// ---------------------------------------------------------------------------

/// An immutable snapshot of a single connected display.
class DisplayBounds {
  /// Platform-specific display identifier (e.g., CGDirectDisplayID on macOS).
  final String id;

  /// Pixel bounds in global screen coordinates (logical pixels).
  final Rect rect;

  /// Logical-to-physical pixel ratio (e.g., 2.0 on a Retina display).
  final double dpiScale;

  /// Whether this is the operating system's primary/main display.
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

// ---------------------------------------------------------------------------
// WindowInfo
// ---------------------------------------------------------------------------

/// An immutable snapshot of a visible OS application window.
class WindowInfo {
  /// OS window identifier (CGWindowID on macOS, HWND integer on Windows).
  final int windowId;

  /// macOS application bundle identifier (e.g., `com.apple.finder`).
  /// `null` on Windows or when unavailable.
  final String? appBundleId;

  /// Window title string. May be `null` when the OS does not expose it.
  final String? windowTitle;

  /// Window frame in global screen coordinates (logical pixels).
  final Rect bounds;

  /// Whether the window is currently minimised to the Dock / taskbar.
  final bool isMinimized;

  /// Whether the window is visible on screen.
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

// ---------------------------------------------------------------------------
// PhysicsEntityState
// ---------------------------------------------------------------------------

/// Immutable snapshot of a single physics-simulated entity at one instant.
///
/// All arithmetic in the physics simulator operates on these fields in a fixed
/// IEEE 754 double-precision order to guarantee deterministic results
/// (requirement 9.7).
class PhysicsEntityState {
  /// Horizontal anchor position in global screen coordinates (logical px).
  final double x;

  /// Vertical anchor position in global screen coordinates (logical px).
  final double y;

  /// Horizontal velocity component (logical px / s).
  final double vx;

  /// Vertical velocity component (logical px / s).
  final double vy;

  /// Bounding-box width (logical px).
  final double width;

  /// Bounding-box height (logical px).
  final double height;

  /// True when the entity is not in contact with any valid surface.
  final bool isAirborne;

  /// True when the entity's velocity has been zeroed after [stationaryTicks]
  /// consecutive sub-threshold ticks.
  final bool isStationary;

  /// Number of consecutive ticks during which `|vx| < 5 && |vy| < 5`.
  /// Resets to 0 whenever either axis exceeds the threshold.
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

  /// Returns a new [PhysicsEntityState] with only the specified fields replaced.
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

// ---------------------------------------------------------------------------
// ThrowableObjectState
// ---------------------------------------------------------------------------

/// Immutable runtime snapshot of one throwable object.
class ThrowableObjectState {
  /// Unique object identifier within a session (matches [PhysicsEntityId] key).
  final int id;

  /// Monotonically increasing spawn counter.  The highest value among active
  /// objects is the pet's current chase target (requirement 7.4).
  final int spawnPriority;

  /// Global screen position where the drag gesture was released.
  final Offset spawnOrigin;

  /// Identifier of this object's entry in the [PhysicsSimulator].
  final PhysicsEntityId physicsId;

  /// Current lifecycle phase.
  final ThrowableLifecycle lifecycle;

  /// Consecutive ticks during which the object's speed was below threshold
  /// (used to advance `flying → stationary` after 3 ticks).
  final int stationaryTickCount;

  /// Wall-clock time at which the object first became stationary.
  /// `null` while still flying or already disposed.
  final DateTime? stationaryAt;

  /// Wall-clock time at which pathfinding to the object first failed.
  /// Reset to `null` when pathfinding succeeds again.
  final DateTime? unreachableSince;

  /// Visual/behavior flavor of the object, e.g. `ball` or `treat`.
  final String kind;

  /// Current center position in the companion game coordinate space.
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

// ---------------------------------------------------------------------------
// PetConfigV2
// ---------------------------------------------------------------------------

/// Persisted settings for the pet companion, format version 2.
///
/// All fields are required at the Dart level; missing fields in a JSON payload
/// fall back to the values returned by [PetConfigV2.defaults()].
class PetConfigV2 {
  /// Active movement mode (free roam, constrained, or single-display).
  final PetMode mode;

  /// Display [DisplayBounds.id] to pin the pet to when [PetMode.singleDisplay]
  /// is active.  `null` in all other modes.
  final String? pinnedDisplayId;

  /// Position and size of the constraint window in global screen coordinates
  /// (used only when [mode] == [PetMode.constrained]).
  final Rect constraintWindowBounds;

  /// Pet's last known anchor point in global screen coordinates.
  /// Restored on next launch to avoid the pet "teleporting" to a default spot.
  final Offset lastAnchorPoint;

  /// Identifier of the active visual theme / sprite pack (e.g., `'grey_cat'`).
  final String themeId;

  /// User-visible display name for the pet.
  final String petName;

  /// Uniform scaling factor applied to the pet sprite.
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

  /// Factory that returns the out-of-the-box configuration used when no
  /// persisted config file exists or when the saved file cannot be parsed.
  factory PetConfigV2.defaults() => const PetConfigV2(
    mode: PetMode.freeRoam,
    pinnedDisplayId: null,
    constraintWindowBounds: Rect.fromLTWH(100, 100, 300, 300),
    lastAnchorPoint: Offset.zero,
    themeId: 'grey_cat',
    petName: 'Mochi',
    scale: 6.0,
  );

  // ---- JSON serialization --------------------------------------------------

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

  // ---- copyWith ------------------------------------------------------------

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

  // ---- equality ------------------------------------------------------------

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

  // ---- private helpers -----------------------------------------------------

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

// ---------------------------------------------------------------------------
// StateTransitionLog
// ---------------------------------------------------------------------------

/// A single entry in the pet state-machine transition log.
///
/// Written by [PetStateMachine._transitionTo()] on every state change and
/// forwarded to [AppLogger.info()] as a structured JSON payload (requirement 8.9).
class StateTransitionLog {
  /// The state the machine was in immediately before this transition.
  final PetState previousState;

  /// The state the machine has entered.
  final PetState newState;

  /// UTC wall-clock timestamp of the transition.
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
