import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:standup/core/native/macos_bridge.dart';
import 'package:standup/core/utils/logger.dart';

/// Service to manage system-wide overlay windows that appear on top of all applications
class OverlayWindowService extends ChangeNotifier {
  final AppLogger _logger = AppLogger();
  bool _isOverlayVisible = false;
  OverlayType? _currentOverlayType;

  /// Show a system-wide overlay window
  Future<void> showOverlay({
    required OverlayType type,
    required WidgetBuilder builder,
    bool strictMode = false,
    bool floatingMode = false,
  }) async {
    if (_isOverlayVisible && _currentOverlayType == type) {
      return;
    }

    try {
      final displays = await ScreenRetriever.instance.getAllDisplays();
      final primaryDisplay = displays.first;
      
      // Try to cover the primary display at minimum
      double width = primaryDisplay.size.width;
      double height = primaryDisplay.size.height;
      double x = 0;
      double y = 0;

      _logger.info('Showing global overlay: $type (Size: ${width}x$height)');

      await windowManager.setIgnoreMouseEvents(false);

      if (floatingMode) {
        await MacOSBridge.setWindowLevel('floating');
        await windowManager.setFullScreen(false);
        await windowManager.setSkipTaskbar(true);
        await windowManager.setHasShadow(false);

        final floatWidth = 350.0;
        final floatHeight = 120.0;
        await windowManager.setSize(Size(floatWidth, floatHeight));
        await windowManager.setPosition(Offset(width - floatWidth - 20, 40));
      } else {
        if (strictMode) {
          await MacOSBridge.setWindowLevel('screenSaver');
          await MacOSBridge.setPresentationOptions(hideDock: true, hideMenu: true);
          await windowManager.setBounds(Rect.fromLTWH(x, y, width, height));
          await windowManager.setFullScreen(true);
        } else {
          await MacOSBridge.setWindowLevel('floating');
          await windowManager.setFullScreen(false);
          await windowManager.setBounds(Rect.fromLTWH(x, y, width, height));
        }
      }

      await windowManager.show();
      await windowManager.focus();

      _isOverlayVisible = true;
      _currentOverlayType = type;
      notifyListeners();
    } catch (e) {
      _logger.error('Failed to show global overlay: $e');
      rethrow;
    }
  }

  /// Restore the window to its dashboard state
  Future<void> showDashboard() async {
    try {
      _logger.info('Restoring dashboard window');
      
      if (_isOverlayVisible) {
        await hideOverlay();
      }

      await MacOSBridge.setWindowLevel('normal');
      await MacOSBridge.setPresentationOptions(hideDock: false, hideMenu: false);
      
      await windowManager.setFullScreen(false);
      await windowManager.setSize(const Size(500, 750));
      await windowManager.setSkipTaskbar(false);
      await windowManager.setHasShadow(true);
      await windowManager.center();
      
      await windowManager.show();
      await windowManager.focus();
      notifyListeners();
    } catch (e) {
      _logger.error('Failed to show dashboard: $e');
    }
  }

  /// Hide the current overlay and return to normal window state
  Future<void> hideOverlay() async {
    if (!_isOverlayVisible) {
      return;
    }

    try {
      _logger.info('Hiding overlay and resetting window state');

      // Reset macOS native state
      await MacOSBridge.setWindowLevel('normal');
      await MacOSBridge.setPresentationOptions(hideDock: false, hideMenu: false);

      await windowManager.setAlwaysOnTop(false);
      await windowManager.setFullScreen(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.hide();
      await windowManager.setBackgroundColor(Colors.transparent);

      _isOverlayVisible = false;
      _currentOverlayType = null;
      notifyListeners();

      _logger.info('Overlay hidden successfully');
    } catch (e) {
      _logger.error('Failed to hide overlay: $e');
    }
  }

  /// Check if overlay is currently visible
  bool get isOverlayVisible => _isOverlayVisible;

  /// Get current overlay type
  OverlayType? get currentOverlayType => _currentOverlayType;

  /// Reset overlay state (use when app is closing)
  Future<void> reset() async {
    _isOverlayVisible = false;
    _currentOverlayType = null;
    await MacOSBridge.setWindowLevel('normal');
    await MacOSBridge.setPresentationOptions(hideDock: false, hideMenu: false);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setFullScreen(false);
    await windowManager.setSkipTaskbar(false);
  }
}

/// Types of overlays supported
enum OverlayType {
  /// Flash notification overlay (short reminder)
  flashNotification,

  /// Break overlay (full break screen)
  breakScreen,

  /// Clock preview overlay (demo mode)
  clockPreview,
}
