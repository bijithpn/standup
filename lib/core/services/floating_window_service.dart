import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:standup/core/utils/logger.dart';

/// Service to manage a floating always-on-top window
/// This window stays visible even when the app is minimized or other apps are in focus
class FloatingWindowService {
  final AppLogger _logger = AppLogger();
  bool _isFloating = false;
  FloatingWindowType? _currentType;
  StreamController<FloatingWindowState>? _stateController;

  /// Stream to listen to floating window state changes
  Stream<FloatingWindowState> get stateStream =>
      (_stateController ??= StreamController<FloatingWindowState>.broadcast())
          .stream;

  /// Show a floating window that stays on top of all other windows
  /// This works even when the main app window is minimized or closed
  Future<void> showFloatingWindow({
    required FloatingWindowType type,
    required Widget content,
    double? width,
    double? height,
    Offset? position,
    bool resizable = false,
    bool showInDock = false,
  }) async {
    if (_isFloating) {
      _logger.warning('Floating window already visible');
      return;
    }

    try {
      // Get display information for positioning
      final displays = await ScreenRetriever.instance.getAllDisplays();
      final primaryDisplay = displays.first;
      final screenWidth = primaryDisplay.size.width;
      final screenHeight = primaryDisplay.size.height;

      // Default dimensions
      final windowWidth = width ?? 400;
      final windowHeight = height ?? 100;

      // Default position: top-right corner of screen
      final defaultX = screenWidth - windowWidth - 20;
      final defaultY = 20;
      final defaultPosition = position ?? Offset(defaultX.toDouble(), defaultY.toDouble());

      _logger.info(
        'Showing floating window: $type at ${defaultPosition.dx}x${defaultPosition.dy} (${windowWidth}x$windowHeight) on screen height $screenHeight',
      );

      // Configure window as floating
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSize(Size(windowWidth, windowHeight));
      await windowManager.setPosition(defaultPosition);
      await windowManager.setResizable(resizable);
      await windowManager.setMinimizable(resizable);
      await windowManager.setClosable(resizable);
      
      // Don't show in dock if it's a small floating window
      if (!showInDock) {
        await windowManager.setSkipTaskbar(true);
      }

      // Make window visible and focused
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setHasShadow(false);

      _isFloating = true;
      _currentType = type;

      _stateController?.add(FloatingWindowState(
        isVisible: true,
        type: type,
      ));

      _logger.info('Floating window shown successfully');
    } catch (e) {
      _logger.error('Failed to show floating window: $e');
      rethrow;
    }
  }

  /// Hide the floating window and restore normal window state
  Future<void> hideFloatingWindow() async {
    if (!_isFloating) {
      return;
    }

    try {
      _logger.info('Hiding floating window');

      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.setHasShadow(true);

      _isFloating = false;
      _currentType = null;

      _stateController?.add(FloatingWindowState(
        isVisible: false,
        type: null,
      ));

      _logger.info('Floating window hidden successfully');
    } catch (e) {
      _logger.error('Failed to hide floating window: $e');
    }
  }

  /// Check if floating window is currently visible
  bool get isFloatingVisible => _isFloating;

  /// Get current floating window type
  FloatingWindowType? get currentFloatingType => _currentType;

  /// Reset floating window state (use when app is closing)
  Future<void> reset() async {
    _isFloating = false;
    _currentType = null;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setHasShadow(true);
  }
}

/// Types of floating windows supported
enum FloatingWindowType {
  /// Clock display (shows current time)
  clock,

  /// Timer countdown display
  timer,

  /// Flash notification (brief alert)
  flashNotification,

  /// Break countdown display
  breakCountdown,

  /// Custom content
  custom,
}

/// State of the floating window
class FloatingWindowState {
  final bool isVisible;
  final FloatingWindowType? type;

  FloatingWindowState({
    required this.isVisible,
    required this.type,
  });

  @override
  String toString() => 'FloatingWindowState(visible: $isVisible, type: $type)';
}
