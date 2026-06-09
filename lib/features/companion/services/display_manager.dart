import 'dart:math' as math;
import 'dart:ui';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

/// Manages connected displays: enumeration, change notifications, and
/// geometry utilities used by the navigation and physics subsystems.
///
/// Requirements: 1.5, 1.6, 2.1, 2.4, 2.5, 2.6, 3.4.
abstract class DisplayManager {
  /// Enumerate all currently connected displays.
  ///
  /// Must complete in < 500 ms (requirement 1.5).  The result is also stored
  /// internally so that [unionBounds] and [nearestDisplayPoint] stay in sync.
  Future<List<DisplayBounds>> enumerateDisplays();

  /// Union rect of all connected displays in global screen coordinates.
  ///
  /// Returns [Rect.zero] when no displays are known.
  Rect get unionBounds;

  /// Return the point on the nearest display boundary to [outside].
  ///
  /// If [outside] is already inside a display rect, it is returned unchanged.
  /// Among all display boundary points, the one with the minimum Euclidean
  /// distance to [outside] is returned (requirement 2.6).
  Offset nearestDisplayPoint(Offset outside);

  /// Return true if [a] and [b] share or overlap by ≥ 1 px along a horizontal
  /// or vertical edge (requirement 2.1).
  bool areAdjacent(DisplayBounds a, DisplayBounds b);

  /// Called once per tick from `CompanionGame.update()`.
  ///
  /// Fast no-op when the display list is unchanged.  When the native layer has
  /// fired a display-change callback since the last [poll], delegates to
  /// [onDisplayChanged] with the new bounds list.
  void poll();

  /// Handle a display-change notification from the native layer.
  ///
  /// - Updates [unionBounds].
  /// - Emits [DisplayDisconnectedEvent] for each previously pinned display
  ///   that is absent from [newBounds].
  /// - Broadcasts the updated bounds via [EventBus].
  void onDisplayChanged(List<DisplayBounds> newBounds);
}

// ---------------------------------------------------------------------------
// Concrete implementation
// ---------------------------------------------------------------------------

/// Default [DisplayManager] implementation backed by [NativeBridgePlatform].
class NativeDisplayManager implements DisplayManager {
  NativeDisplayManager({
    NativeBridgePlatform? bridge,
    EventBus? eventBus,
    AppLogger? logger,
  }) : _bridge = bridge ?? NativeBridge.instance,
       _eventBus = eventBus ?? EventBus.instance,
       _logger = logger ?? AppLogger() {
    // Register the native display-change callback on construction so events
    // received before the first enumerateDisplays() call are queued.
    _bridge.registerDisplayChangeCallback(_onNativeDisplayChange);
  }

  final NativeBridgePlatform _bridge;
  final EventBus _eventBus;
  final AppLogger _logger;

  /// The last successfully enumerated set of displays.
  List<DisplayBounds> _displays = [];

  /// Cached union of all [_displays] rects.
  Rect _unionBounds = Rect.zero;

  /// Pending display list delivered by the native callback but not yet
  /// processed by [poll].
  List<NativeDisplayInfo>? _pendingNativeChange;

  /// IDs of displays that are considered "pinned" (i.e., the set of IDs
  /// present the last time [onDisplayChanged] was called).  Used to detect
  /// disconnections for [DisplayDisconnectedEvent].
  Set<String> _previousDisplayIds = {};

  // ---- DisplayManager interface -------------------------------------------

  @override
  Future<List<DisplayBounds>> enumerateDisplays() async {
    final displayInfoList = await _bridge.enumerateDisplays();
    final rawList = displayInfoList.map((info) => info.toMap()).toList();
    final bounds = rawList.map(_parseDisplayMap).toList();
    _displays = bounds;
    _unionBounds = _computeUnion(bounds);
    _previousDisplayIds = bounds.map((d) => d.id).toSet();
    _logger.info(
      'DisplayManager: enumerated ${bounds.length} display(s), '
      'union=$_unionBounds',
    );
    return List.unmodifiable(bounds);
  }

  @override
  Rect get unionBounds => _unionBounds;

  @override
  Offset nearestDisplayPoint(Offset outside) {
    if (_displays.isEmpty) return outside;

    // Fast path: point is already inside one of the display rects.
    for (final d in _displays) {
      if (d.rect.contains(outside)) return outside;
    }

    // Find the display boundary point with the minimum Euclidean distance.
    Offset best = _clampToRect(outside, _displays.first.rect);
    double bestDist = _euclidean(outside, best);

    for (final d in _displays.skip(1)) {
      final candidate = _clampToRect(outside, d.rect);
      final dist = _euclidean(outside, candidate);
      if (dist < bestDist) {
        best = candidate;
        bestDist = dist;
      }
    }

    return best;
  }

  @override
  bool areAdjacent(DisplayBounds a, DisplayBounds b) {
    // Two displays are adjacent when they share at least 1 px of a horizontal
    // or vertical *edge* (not just a single corner point).
    //
    // Overlapping displays are also considered adjacent.
    final ar = a.rect;
    final br = b.rect;

    // If they already overlap, they are adjacent.
    if (ar.overlaps(br)) return true;

    // Shared horizontal boundary: rects line up horizontally and their
    // vertical edges touch (top of one == bottom of the other).
    final sharedHorizLeft = ar.left > br.left ? ar.left : br.left;
    final sharedHorizRight = ar.right < br.right ? ar.right : br.right;
    if (sharedHorizRight > sharedHorizLeft) {
      if (ar.top == br.bottom || ar.bottom == br.top) return true;
    }

    // Shared vertical boundary: rects line up vertically and their
    // horizontal edges touch (left of one == right of the other).
    final sharedVertTop = ar.top > br.top ? ar.top : br.top;
    final sharedVertBottom = ar.bottom < br.bottom ? ar.bottom : br.bottom;
    if (sharedVertBottom > sharedVertTop) {
      if (ar.left == br.right || ar.right == br.left) return true;
    }

    return false;
  }

  @override
  void poll() {
    final pending = _pendingNativeChange;
    if (pending == null) return; // fast no-op
    _pendingNativeChange = null;
    final rawList = pending.map((info) => info.toMap()).toList();
    final newBounds = rawList.map(_parseDisplayMap).toList();
    onDisplayChanged(newBounds);
  }

  @override
  void onDisplayChanged(List<DisplayBounds> newBounds) {
    final newIds = newBounds.map((d) => d.id).toSet();

    // Emit disconnection events for displays that have gone away.
    for (final prevId in _previousDisplayIds) {
      if (!newIds.contains(prevId)) {
        _logger.warning('DisplayManager: display "$prevId" disconnected.');
        _eventBus.emit(DisplayDisconnectedEvent(displayId: prevId));
      }
    }

    _displays = newBounds;
    _unionBounds = _computeUnion(newBounds);
    _previousDisplayIds = newIds;

    _logger.info(
      'DisplayManager: display list updated — ${newBounds.length} display(s), '
      'union=$_unionBounds',
    );

    // Broadcast updated bounds so subscribers (NavigationService, Physics,
    // etc.) can react within the same tick.
    _eventBus.emit(DisplayChangedEvent());
  }

  // ---- Native callback (runs on platform thread / isolate boundary) --------

  void _onNativeDisplayChange(List<NativeDisplayInfo> displays) {
    // Store for processing on the next poll() call from the game loop so all
    // display-change logic runs safely on the Flutter UI isolate.
    _pendingNativeChange = displays;
  }

  // ---- Private helpers -----------------------------------------------------

  /// Parse a raw display map from [NativeBridgePlatform.enumerateDisplays].
  ///
  /// Expected keys: `id`, `x`, `y`, `width`, `height`, `dpiScale`,
  /// `isPrimary`.
  static DisplayBounds _parseDisplayMap(Map<String, dynamic> map) {
    final id = map['id'] as String? ?? '';
    final x = (map['x'] as num?)?.toDouble() ?? 0.0;
    final y = (map['y'] as num?)?.toDouble() ?? 0.0;
    final width = (map['width'] as num?)?.toDouble() ?? 0.0;
    final height = (map['height'] as num?)?.toDouble() ?? 0.0;
    final dpiScale = (map['dpiScale'] as num?)?.toDouble() ?? 1.0;
    final isPrimary = map['isPrimary'] as bool? ?? false;

    return DisplayBounds(
      id: id,
      rect: Rect.fromLTWH(x, y, width, height),
      dpiScale: dpiScale,
      isPrimary: isPrimary,
    );
  }

  /// Compute the bounding union of all display rects.
  static Rect _computeUnion(List<DisplayBounds> displays) {
    if (displays.isEmpty) return Rect.zero;
    var result = displays.first.rect;
    for (final d in displays.skip(1)) {
      result = result.expandToInclude(d.rect);
    }
    return result;
  }

  /// Clamp [point] to the nearest point *on the boundary or interior* of
  /// [rect], i.e., a point that is inside or on the edge of [rect].
  static Offset _clampToRect(Offset point, Rect rect) {
    final clampedX = point.dx.clamp(rect.left, rect.right);
    final clampedY = point.dy.clamp(rect.top, rect.bottom);
    return Offset(clampedX, clampedY);
  }

  /// Euclidean distance between two offsets.
  static double _euclidean(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
