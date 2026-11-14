import 'package:breakmate/core/errors/error_handler.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';

const _channel = MethodChannel('com.breakmate/window');

/// Thin wrapper over the native window channel (macOS) for level, position, opacity and click-through; errors are reported, never thrown.
class WindowService {
  WindowService._();
  static final WindowService instance = WindowService._();
  final _logger = AppLogger();

  Future<void> setWindowLevel(String level) async {
    try {
      await _channel.invokeMethod('setWindowLevel', {'level': level});
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> setWindowPosition({
    required double x,
    required double y,
    bool animate = true,
  }) async {
    try {
      await _channel.invokeMethod('setWindowPosition', {
        'x': x,
        'y': y,
        'animate': animate,
      });
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
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
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  // Returns 0,0 on failure so callers always get a usable position.
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
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> setIgnoresMouseEvents(bool ignore) async {
    try {
      await _channel.invokeMethod('setIgnoresMouseEvents', {'ignore': ignore});
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> setHasShadow(bool hasShadow) async {
    try {
      await _channel.invokeMethod('setHasShadow', {'hasShadow': hasShadow});
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> setAcceptsMouseMovedEvents(bool accept) async {
    try {
      await _channel.invokeMethod('setAcceptsMouseMovedEvents', {
        'accept': accept,
      });
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> orderFrontRegardless() async {
    try {
      await _channel.invokeMethod('orderFrontRegardless');
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> hideWindow() async {
    try {
      await _channel.invokeMethod('hideWindow');
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> showWindow() async {
    try {
      await _channel.invokeMethod('showWindow');
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> setWindowStyle(String style) async {
    try {
      await _channel.invokeMethod('setWindowStyle', {'style': style});
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> startDrag() async {
    try {
      await _channel.invokeMethod('startDrag');
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }

  Future<void> setNonActivating(bool nonActivating) async {
    try {
      await _channel.invokeMethod('setNonActivating', {
        'nonActivating': nonActivating,
      });
    } catch (e, st) {
      ErrorHandler().handleError(e, st);
    }
  }
}
