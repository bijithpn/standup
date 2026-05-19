import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
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
      _logger.info('Showing global overlay: $type');

      await windowManager.setIgnoreMouseEvents(false);

      if (type != OverlayType.clockPreview) {
        // Use native multi-monitor overlay for all real overlays
        await MacOSBridge.showOverlay({'type': type.name});
        if (strictMode && type == OverlayType.breakScreen) {
          await MacOSBridge.setPresentationOptions(hideDock: true, hideMenu: true);
        }
        // Always hide the main window when showing a system-level overlay
        await windowManager.hide();
      } else {
        // Clock preview still uses main window for simplicity
        await MacOSBridge.setWindowLevel('floating');
        await windowManager.show();
        await windowManager.focus();
      }

      _isOverlayVisible = true;
      _currentOverlayType = type;
      notifyListeners();
    } catch (e) {
      _logger.error('Failed to show global overlay: ');
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

      await MacOSBridge.hideOverlay();
      await MacOSBridge.setPresentationOptions(hideDock: false, hideMenu: false);
      await MacOSBridge.setWindowLevel('normal');

      _isOverlayVisible = false;
      _currentOverlayType = null;

      await windowManager.setAlwaysOnTop(false);
      await windowManager.setFullScreen(false);
      await windowManager.setSize(const Size(1100, 750));
      await windowManager.setSkipTaskbar(false);
      await windowManager.setHasShadow(true);
      await windowManager.setIgnoreMouseEvents(false);
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.center();

      await windowManager.show();
      await windowManager.focus();
      await MacOSBridge.focusApp();
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
      await MacOSBridge.hideOverlay();
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
      _logger.error('Failed to hide overlay: ');
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
    await MacOSBridge.hideOverlay();
    await MacOSBridge.setPresentationOptions(hideDock: false, hideMenu: false);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setFullScreen(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setIgnoreMouseEvents(false);
  }
}

/// Types of overlays supported
enum OverlayType {
  /// Flash notification overlay (short reminder)
  flashNotification,

  /// Pre-break warning overlay
  preBreakWarning,

  /// Break overlay (full break screen)
  breakScreen,

  /// Clock preview overlay (demo mode)
  clockPreview,
}
