import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:breakmate/core/utils/logger.dart';

class FloatingWindowService {
  final AppLogger _logger = AppLogger();
  bool _isFloating = false;
  FloatingWindowType? _currentType;
  StreamController<FloatingWindowState>? _stateController;

  Stream<FloatingWindowState> get stateStream =>
      (_stateController ??= StreamController<FloatingWindowState>.broadcast())
          .stream;

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
      final displays = await ScreenRetriever.instance.getAllDisplays();
      final primaryDisplay = displays.first;
      final screenWidth = primaryDisplay.size.width;
      final screenHeight = primaryDisplay.size.height;

      final windowWidth = width ?? 400;
      final windowHeight = height ?? 100;

      final defaultX = screenWidth - windowWidth - 20;
      final defaultY = 20;
      final defaultPosition =
          position ?? Offset(defaultX.toDouble(), defaultY.toDouble());

      _logger.info(
        'Showing floating window: $type at ${defaultPosition.dx}x${defaultPosition.dy} (${windowWidth}x$windowHeight) on screen height $screenHeight',
      );

      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSize(Size(windowWidth, windowHeight));
      await windowManager.setPosition(defaultPosition);
      await windowManager.setResizable(resizable);
      await windowManager.setMinimizable(resizable);
      await windowManager.setClosable(resizable);

      if (!showInDock) {
        await windowManager.setSkipTaskbar(true);
      }

      await windowManager.show();
      await windowManager.focus();
      await windowManager.setHasShadow(false);

      _isFloating = true;
      _currentType = type;

      _stateController?.add(FloatingWindowState(isVisible: true, type: type));

      _logger.info('Floating window shown successfully');
    } catch (e) {
      _logger.error('Failed to show floating window: $e');
      rethrow;
    }
  }

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

      _stateController?.add(FloatingWindowState(isVisible: false, type: null));

      _logger.info('Floating window hidden successfully');
    } catch (e) {
      _logger.error('Failed to hide floating window: $e');
    }
  }

  bool get isFloatingVisible => _isFloating;

  FloatingWindowType? get currentFloatingType => _currentType;

  Future<void> reset() async {
    _isFloating = false;
    _currentType = null;
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setHasShadow(true);
  }
}

enum FloatingWindowType { clock, timer, breakCountdown, custom }

class FloatingWindowState {
  final bool isVisible;
  final FloatingWindowType? type;

  FloatingWindowState({required this.isVisible, required this.type});

  @override
  String toString() => 'FloatingWindowState(visible: $isVisible, type: $type)';
}
