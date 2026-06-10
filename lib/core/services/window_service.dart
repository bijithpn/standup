import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';

const _channel = MethodChannel('com.breakmate/window');

class WindowService {
  WindowService._();
  static final WindowService instance = WindowService._();
  final _logger = AppLogger();

  Future<void> setWindowLevel(String level) async {
    try {
      await _channel.invokeMethod('setWindowLevel', {'level': level});
    } catch (e) {
      _logger.error('Failed to set window level: $e');
    }
  }

  Future<void> setWindowPosition({required double x, required double y}) async {
    try {
      await _channel.invokeMethod('setWindowPosition', {'x': x, 'y': y});
    } catch (e) {
      _logger.error('Failed to set window position: $e');
    }
  }

  Future<void> setWindowSize({
    required double width,
    required double height,
  }) async {
    try {
      await _channel.invokeMethod('setWindowSize', {
        'width': width,
        'height': height,
      });
    } catch (e) {
      _logger.error('Failed to set window size: $e');
    }
  }

  Future<Map<String, dynamic>> getWindowPosition() async {
    try {
      final result = await _channel.invokeMethod('getWindowPosition');
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      _logger.error('Failed to get window position: $e');
      return {'x': 0.0, 'y': 0.0};
    }
  }

  Future<void> setWindowOpacity(double opacity) async {
    try {
      await _channel.invokeMethod('setWindowOpacity', {'opacity': opacity});
    } catch (e) {
      _logger.error('Failed to set window opacity: $e');
    }
  }

  Future<void> setIgnoresMouseEvents(bool ignore) async {
    try {
      await _channel.invokeMethod('setIgnoresMouseEvents', {'ignore': ignore});
    } catch (e) {
      _logger.error('Failed to set ignores mouse events: $e');
    }
  }

  Future<void> setHasShadow(bool hasShadow) async {
    try {
      await _channel.invokeMethod('setHasShadow', {'hasShadow': hasShadow});
    } catch (e) {
      _logger.error('Failed to set shadow: $e');
    }
  }

  Future<void> setAcceptsMouseMovedEvents(bool accept) async {
    try {
      await _channel.invokeMethod('setAcceptsMouseMovedEvents', {
        'accept': accept,
      });
    } catch (e) {
      _logger.error('Failed to set accepts mouse moved: $e');
    }
  }

  Future<void> orderFrontRegardless() async {
    try {
      await _channel.invokeMethod('orderFrontRegardless');
    } catch (e) {
      _logger.error('Failed to order front: $e');
    }
  }

  Future<void> hideWindow() async {
    try {
      await _channel.invokeMethod('hideWindow');
    } catch (e) {
      _logger.error('Failed to hide window: $e');
    }
  }

  Future<void> showWindow() async {
    try {
      await _channel.invokeMethod('showWindow');
    } catch (e) {
      _logger.error('Failed to show window: $e');
    }
  }

  Future<void> setWindowStyle(String style) async {
    try {
      await _channel.invokeMethod('setWindowStyle', {'style': style});
    } catch (e) {
      _logger.error('Failed to set window style: $e');
    }
  }

  /// Initiates a native window-drag gesture (macOS `performWindowDragWithEvent` /
  /// Windows `ReleaseCapture` + `PostMessage WM_NCLBUTTONDOWN`).
  /// This delegates window repositioning entirely to the OS so Flutter never
  /// needs to track pointer deltas for the drag handle.
  Future<void> startDrag() async {
    try {
      await _channel.invokeMethod('startDrag');
    } catch (e) {
      _logger.error('Failed to start window drag: $e');
    }
  }

  /// Configures the window as non-activating:
  /// macOS: sets `styleMask` to include `NSWindowStyleMaskNonactivatingPanel`
  ///   or `canBecomeKey = false`.
  /// Windows: applies `WS_EX_NOACTIVATE` extended window style.
  /// Call once during [initialize] so click events never steal focus from the
  /// user's current application .
  Future<void> setNonActivating(bool nonActivating) async {
    try {
      await _channel.invokeMethod('setNonActivating', {
        'nonActivating': nonActivating,
      });
    } catch (e) {
      _logger.error('Failed to set non-activating style: $e');
    }
  }
}
