import 'dart:ui';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/native/native_bridge.dart' as native;
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';

abstract class WindowMonitor {
  Future<List<WindowInfo>> queryVisibleWindows();

  bool isStandingOn(Rect petBounds, WindowInfo window);

  WindowInfo? currentPlatform(Rect petBounds, List<WindowInfo> windows);
}

class NativeWindowMonitor implements WindowMonitor {
  NativeWindowMonitor({
    native.NativeBridgePlatform? bridge,
    EventBus? eventBus,
    AppLogger? logger,
  }) : _bridge = bridge ?? native.NativeBridge.instance,
       _eventBus = eventBus ?? EventBus.instance,
       _logger = logger ?? AppLogger();

  final native.NativeBridgePlatform _bridge;
  final EventBus _eventBus;
  final AppLogger _logger;

  List<WindowInfo> _previousWindows = [];
  bool _wasOverlapping = false;
  int? _standingWindowId;

  @override
  Future<List<WindowInfo>> queryVisibleWindows() async {
    final nativeWindows = await _bridge.getVisibleWindows();
    return nativeWindows
        .map(_parseNativeWindowInfo)
        .where((w) => w.isVisible && !w.isMinimized)
        .toList();
  }

  static WindowInfo _parseNativeWindowInfo(native.WindowInfo nativeWin) {
    return WindowInfo(
      windowId: int.tryParse(nativeWin.windowId) ?? 0,
      appBundleId: null, // not available from native bridge
      windowTitle: nativeWin.windowTitle,
      bounds: Rect.fromLTWH(
        nativeWin.x,
        nativeWin.y,
        nativeWin.width,
        nativeWin.height,
      ),
      isMinimized: nativeWin.isMinimized,
      isVisible: nativeWin.isVisible,
    );
  }

  @override
  bool isStandingOn(Rect petBounds, WindowInfo window) {
    // Pet's lower edge must be within 2 px of the window's top edge.
    final double lowerEdge = petBounds.bottom;
    final double windowTop = window.bounds.top;
    if ((lowerEdge - windowTop).abs() > 2.0) return false;

    // Horizontal extents must overlap.
    return petBounds.left < window.bounds.right &&
        petBounds.right > window.bounds.left;
  }

  @override
  WindowInfo? currentPlatform(Rect petBounds, List<WindowInfo> windows) {
    for (final w in windows) {
      if (isStandingOn(petBounds, w)) return w;
    }
    return null;
  }

  Future<void> update(Rect petBounds) async {
    final windows = await queryVisibleWindows();
    _diffAndEmit(petBounds, windows);
    _previousWindows = windows;
  }

  void _diffAndEmit(Rect petBounds, List<WindowInfo> currentWindows) {
    final bool nowOverlapping = currentWindows.any(
      (w) => petBounds.overlaps(w.bounds),
    );

    if (nowOverlapping && !_wasOverlapping) {
      _eventBus.emit(PetWindowOverlapEvent(started: true));
      _logger.info('WindowMonitor: pet window overlap started');
    } else if (!nowOverlapping && _wasOverlapping) {
      _eventBus.emit(PetWindowOverlapEvent(started: false));
      _logger.info('WindowMonitor: pet window overlap ended');
    }
    _wasOverlapping = nowOverlapping;

    final WindowInfo? currentStanding = currentPlatform(
      petBounds,
      currentWindows,
    );

    if (_standingWindowId != null) {
      final WindowInfo? previousStandingWindow = _previousWindows
          .cast<WindowInfo?>()
          .firstWhere(
            (w) => w?.windowId == _standingWindowId,
            orElse: () => null,
          );

      if (previousStandingWindow != null) {
        final WindowInfo? stillPresent = currentWindows
            .cast<WindowInfo?>()
            .firstWhere(
              (w) => w?.windowId == _standingWindowId,
              orElse: () => null,
            );

        if (stillPresent == null) {
          _eventBus.emit(PetStandingSurfaceLostEvent());
          _logger.info(
            'WindowMonitor: standing surface lost (windowId=$_standingWindowId)',
          );
          _standingWindowId = null;
        } else if (stillPresent.bounds != previousStandingWindow.bounds) {
          _eventBus.emit(
            PetStandingWindowMovedEvent(newBounds: stillPresent.bounds),
          );
          _logger.info(
            'WindowMonitor: standing window moved/resized '
            '(windowId=$_standingWindowId, newBounds=${stillPresent.bounds})',
          );
        }
      }
    }

    _standingWindowId = currentStanding?.windowId;
  }
}
