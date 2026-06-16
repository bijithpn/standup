import 'dart:math' as math;
import 'dart:ui';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';

abstract class DisplayManager {
  Future<List<DisplayBounds>> enumerateDisplays();

  List<DisplayBounds> get displays;

  Rect get unionBounds;

  Offset nearestDisplayPoint(Offset outside);

  bool areAdjacent(DisplayBounds a, DisplayBounds b);

  void poll();

  void onDisplayChanged(List<DisplayBounds> newBounds);
}

class NativeDisplayManager implements DisplayManager {
  NativeDisplayManager({
    NativeBridgePlatform? bridge,
    EventBus? eventBus,
    AppLogger? logger,
  }) : _bridge = bridge ?? NativeBridge.instance,
       _eventBus = eventBus ?? EventBus.instance,
       _logger = logger ?? AppLogger() {
    _bridge.registerDisplayChangeCallback(_onNativeDisplayChange);
  }

  final NativeBridgePlatform _bridge;
  final EventBus _eventBus;
  final AppLogger _logger;

  List<DisplayBounds> _displays = [];

  @override
  List<DisplayBounds> get displays => _displays;

  Rect _unionBounds = Rect.zero;

  List<NativeDisplayInfo>? _pendingNativeChange;

  Set<String> _previousDisplayIds = {};

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

    for (final d in _displays) {
      if (d.rect.contains(outside)) return outside;
    }

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
    final ar = a.rect;
    final br = b.rect;

    if (ar.overlaps(br)) return true;

    final sharedHorizLeft = ar.left > br.left ? ar.left : br.left;
    final sharedHorizRight = ar.right < br.right ? ar.right : br.right;
    if (sharedHorizRight > sharedHorizLeft) {
      if (ar.top == br.bottom || ar.bottom == br.top) return true;
    }

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
    if (pending == null) return;
    _pendingNativeChange = null;
    final rawList = pending.map((info) => info.toMap()).toList();
    final newBounds = rawList.map(_parseDisplayMap).toList();
    onDisplayChanged(newBounds);
  }

  @override
  void onDisplayChanged(List<DisplayBounds> newBounds) {
    final newIds = newBounds.map((d) => d.id).toSet();

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

    _eventBus.emit(DisplayChangedEvent());
  }

  void _onNativeDisplayChange(List<NativeDisplayInfo> displays) {
    _pendingNativeChange = displays;
  }

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

  static Rect _computeUnion(List<DisplayBounds> displays) {
    if (displays.isEmpty) return Rect.zero;
    var result = displays.first.rect;
    for (final d in displays.skip(1)) {
      result = result.expandToInclude(d.rect);
    }
    return result;
  }

  static Offset _clampToRect(Offset point, Rect rect) {
    final clampedX = point.dx.clamp(rect.left, rect.right);
    final clampedY = point.dy.clamp(rect.top, rect.bottom);
    return Offset(clampedX, clampedY);
  }

  static double _euclidean(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
