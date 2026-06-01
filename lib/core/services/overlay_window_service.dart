import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Service to manage system-wide overlay windows that appear on top of all applications
class OverlayWindowService extends ChangeNotifier {
  final AppLogger _logger = AppLogger();
  bool _isOverlayVisible = false;
  OverlayType? _currentOverlayType;
  bool _wasMainVisibleBeforeOverlay = false;
  static const MethodChannel _windowsChannel = MethodChannel(
    'com.breakmate/overlay_window',
  );

  /// Show a system-wide overlay window
  Future<void> showOverlay({
    required OverlayType type,
    required WidgetBuilder builder,
    bool strictMode = false,
    bool floatingMode = false,
    bool showOnAllDisplays = true,
    String breakTheme = 'random',
    String? reminderType,
    Map<String, dynamic>? overlayData,
  }) async {
    if (_isOverlayVisible && _currentOverlayType == type) {
      if (type != OverlayType.clockPreview) {
        // If the overlay is already showing, we can still update its data in real-time
        final args = <String, dynamic>{
          'type': type.name,
          'showOnAllDisplays': showOnAllDisplays,
          'theme': breakTheme,
          'isTransparent': type == OverlayType.quickReminder,
          'ignoreMouseEvents': type == OverlayType.quickReminder,
          ...?overlayData,
        };
        if (reminderType != null) args['reminderType'] = reminderType;
        await NativeBridge.showOverlay(args);
      }
      return;
    }

    if (!_isOverlayVisible) {
      _wasMainVisibleBeforeOverlay = await windowManager.isVisible();
      _logger.info(
        'Main window visibility status before overlay: $_wasMainVisibleBeforeOverlay',
      );
    }

    try {
      _logger.info('Showing global overlay: $type');

      await windowManager.setIgnoreMouseEvents(false);

      if (type != OverlayType.clockPreview) {
        if (Platform.isWindows) {
          // Use unified bridge for Windows overlay configuration
          final args = <String, dynamic>{
            'type': type.name,
            'showOnAllDisplays': showOnAllDisplays,
            'theme': breakTheme,
            'isTransparent': type == OverlayType.quickReminder,
            'ignoreMouseEvents': type == OverlayType.quickReminder,
            ...?overlayData,
          };
          if (reminderType != null) args['reminderType'] = reminderType;
          await NativeBridge.showOverlay(args);
          await windowManager.setFullScreen(true);
          await windowManager.setAlwaysOnTop(true);
          await windowManager.show();
          if (strictMode && type == OverlayType.breakScreen) {
            await windowManager.focus();
          }
        } else if (Platform.isMacOS) {
          // Use native multi-monitor overlay for all real overlays
          final args = <String, dynamic>{
            'type': type.name,
            'showOnAllDisplays': showOnAllDisplays,
            'theme': breakTheme,
            'isTransparent': type == OverlayType.quickReminder,
            'ignoreMouseEvents': type == OverlayType.quickReminder,
            ...?overlayData,
          };
          if (reminderType != null) args['reminderType'] = reminderType;
          await NativeBridge.showOverlay(args);
          if (strictMode && type == OverlayType.breakScreen) {
            await NativeBridge.setPresentationOptions(
              hideDock: true,
              hideMenu: true,
            );
          }

          // Only hide the main window for the full break screen.
          // Quick reminders should not interfere with the main window's visibility.
          if (type == OverlayType.breakScreen) {
            Future.delayed(const Duration(milliseconds: 200), () {
              windowManager.hide();
            });
          }
        }
      } else {
        // Clock preview still uses main window for simplicity
        if (Platform.isMacOS) {
          await NativeBridge.setWindowLevel('floating');
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
  Future<void> showDashboard({bool forceShow = false}) async {
    try {
      _logger.info('Restoring dashboard window');

      if (_isOverlayVisible) {
        await hideOverlay();
      }

      if (!_wasMainVisibleBeforeOverlay && !forceShow) {
        _logger.info(
          'Bypassing dashboard focus/activation because main window was hidden/closed before overlay',
        );
        return;
      }

      if (Platform.isWindows) {
        await _windowsChannel.invokeMethod('resetToNormal');
      } else if (Platform.isMacOS) {
        await NativeBridge.hideOverlay(restoreMainWindow: true);
        await NativeBridge.setPresentationOptions(
          hideDock: false,
          hideMenu: false,
        );
        await NativeBridge.setWindowLevel('normal');
      }

      _isOverlayVisible = false;
      _currentOverlayType = null;

      await Future.wait([
        windowManager.setAlwaysOnTop(false),
        windowManager.setFullScreen(false),
        windowManager.setSize(const Size(1100, 750)),
        windowManager.setSkipTaskbar(false),
        windowManager.setHasShadow(true),
        windowManager.setIgnoreMouseEvents(false),
        windowManager.setBackgroundColor(
          Platform.isWindows ? AppTheme.sidebarBackground : Colors.transparent,
        ),
      ]);

      await windowManager.center();

      bool isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        await windowManager.restore();
      }

      await windowManager.show();
      await windowManager.focus();
      if (Platform.isMacOS) {
        await NativeBridge.focusApp();
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
        await NativeBridge.hideOverlay(
          restoreMainWindow: _wasMainVisibleBeforeOverlay,
        );
        await NativeBridge.setPresentationOptions(
          hideDock: false,
          hideMenu: false,
        );
      }

      await windowManager.setAlwaysOnTop(false);
      await windowManager.setFullScreen(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.hide();
      await windowManager.setBackgroundColor(
        Platform.isWindows ? AppTheme.sidebarBackground : Colors.transparent,
      );

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
      await NativeBridge.hideOverlay();
      await NativeBridge.setPresentationOptions(
        hideDock: false,
        hideMenu: false,
      );
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

  /// Quick transparent health reminder
  quickReminder,
}
