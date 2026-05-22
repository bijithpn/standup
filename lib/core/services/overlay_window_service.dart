import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:standup/core/native/macos_bridge.dart';
import 'package:standup/core/utils/logger.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:standup/shared/theme/app_theme.dart';

/// Service to manage system-wide overlay windows that appear on top of all applications
class OverlayWindowService extends ChangeNotifier {
  final AppLogger _logger = AppLogger();
  bool _isOverlayVisible = false;
  OverlayType? _currentOverlayType;
  static const MethodChannel _windowsChannel = MethodChannel('com.standup/overlay_window');

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
        if (Platform.isWindows) {
          // Use unified bridge for Windows overlay configuration
          await MacOSBridge.showOverlay({'type': type.name});
          await windowManager.setFullScreen(true);
          await windowManager.setAlwaysOnTop(true);
          await windowManager.show();
          if (strictMode && type == OverlayType.breakScreen) {
            await windowManager.focus();
          }
        } else if (Platform.isMacOS) {
          // Use native multi-monitor overlay for all real overlays
          await MacOSBridge.showOverlay({'type': type.name});
          if (strictMode && type == OverlayType.breakScreen) {
            await MacOSBridge.setPresentationOptions(hideDock: true, hideMenu: true);
          }
          // Always hide the main window when showing a system-level overlay
          await windowManager.hide();
        }
      } else {
        // Clock preview still uses main window for simplicity
        if (Platform.isMacOS) {
          await MacOSBridge.setWindowLevel('floating');
        }
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

      if (Platform.isWindows) {
        await _windowsChannel.invokeMethod('resetToNormal');
      } else if (Platform.isMacOS) {
        await MacOSBridge.hideOverlay();
        await MacOSBridge.setPresentationOptions(hideDock: false, hideMenu: false);
        await MacOSBridge.setWindowLevel('normal');
      }

      _isOverlayVisible = false;
      _currentOverlayType = null;

      await windowManager.setAlwaysOnTop(false);
      await windowManager.setFullScreen(false);
      await windowManager.setSize(const Size(1100, 750));
      await windowManager.setSkipTaskbar(false);
      await windowManager.setHasShadow(true);
      await windowManager.setIgnoreMouseEvents(false);
      await windowManager.setBackgroundColor(Platform.isWindows ? AppTheme.sidebarBackground : Colors.transparent);
      await windowManager.center();

      await windowManager.show();
      await windowManager.focus();
      if (Platform.isMacOS) {
        await MacOSBridge.focusApp();
      }
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

      // Reset native state
      if (Platform.isWindows) {
        await _windowsChannel.invokeMethod('resetToNormal');
      } else if (Platform.isMacOS) {
        await MacOSBridge.hideOverlay();
        await MacOSBridge.setPresentationOptions(hideDock: false, hideMenu: false);
      }

      await windowManager.setAlwaysOnTop(false);
      await windowManager.setFullScreen(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.hide();
      await windowManager.setBackgroundColor(Platform.isWindows ? AppTheme.sidebarBackground : Colors.transparent);

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
    if (Platform.isWindows) {
      await _windowsChannel.invokeMethod('resetToNormal');
    } else if (Platform.isMacOS) {
      await MacOSBridge.hideOverlay();
      await MacOSBridge.setPresentationOptions(hideDock: false, hideMenu: false);
    }
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setFullScreen(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setIgnoreMouseEvents(false);
  }
}

/// Types of overlays supported
enum OverlayType {


  /// Pre-break warning overlay
  preBreakWarning,

  /// Break overlay (full break screen)
  breakScreen,

  /// Clock preview overlay (demo mode)
  clockPreview,
}
