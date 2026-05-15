import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:standup/core/native/macos_bridge.dart';
import 'package:standup/core/utils/logger.dart';

/// Service to manage system-wide overlay windows that appear on top of all applications
class OverlayWindowService {
  final AppLogger _logger = AppLogger();
  bool _isOverlayVisible = false;
  OverlayType? _currentOverlayType;

  /// Show a system-wide overlay window
  /// This creates a borderless window that appears on top of all applications
  Future<void> showOverlay({
    required OverlayType type,
    required WidgetBuilder builder,
    bool strictMode = false,
    bool floatingMode = false,
  }) async {
    if (_isOverlayVisible) {
      _logger.warning('Overlay already visible, skipping');
      return;
    }

    try {
      // Get the primary display dimensions
      final displays = await ScreenRetriever.instance.getAllDisplays();
      final primaryDisplay = displays.first;
      final screenWidth = primaryDisplay.size.width;
      final screenHeight = primaryDisplay.size.height;

      _logger.info('Showing overlay: $type (strict: $strictMode)');

      if (floatingMode) {
        // Floating mode: smaller window that stays on top
        await MacOSBridge.setWindowLevel('floating');
        await windowManager.setFullScreen(false);
        await windowManager.setSkipTaskbar(true);
        await windowManager.setHasShadow(false);

        // Position in top-right corner for floating mode
        final floatWidth = 350.0;
        final floatHeight = 100.0;
        await windowManager.setSize(Size(floatWidth, floatHeight));
        await windowManager.setPosition(
          Offset(screenWidth - floatWidth - 20, 20),
        );
      } else {
        // Full screen overlay mode
        if (strictMode) {
          // Native screenSaver level to bypass full-screen apps and system UI
          await MacOSBridge.setWindowLevel('screenSaver');
          await MacOSBridge.setPresentationOptions(hideDock: true, hideMenu: true);
        } else {
          await MacOSBridge.setWindowLevel('floating');
        }

        await windowManager.setFullScreen(strictMode);
        await windowManager.setSize(Size(screenWidth, screenHeight));
        await windowManager.setPosition(Offset.zero);
      }

      // Make window visible and focused
      await windowManager.show();
      await windowManager.focus();

      _isOverlayVisible = true;
      _currentOverlayType = type;

      _logger.info('Overlay shown successfully');
    } catch (e) {
      _logger.error('Failed to show overlay: $e');
      rethrow;
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
