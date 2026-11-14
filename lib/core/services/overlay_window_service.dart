import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/core/errors/error_handler.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

/// Shows and hides full-screen overlays (break, pre-break, reminders) through NativeBridge and restores the main window afterwards.
class OverlayWindowService extends ChangeNotifier {
  final AppLogger _logger = AppLogger();
  bool _isOverlayVisible = false;
  OverlayType? _currentOverlayType;
  // Remembers whether the dashboard was open so hideOverlay only restores it then.
  bool _wasMainVisibleBeforeOverlay = false;
  static const MethodChannel _windowsChannel = MethodChannel(
    'com.breakmate/overlay_window',
  );

  /// Shows [type] on all or the primary display; a repeat call for the already-visible type only refreshes native overlay args.
  Future<void> showOverlay({
    required OverlayType type,
    required WidgetBuilder builder,
    bool strictMode = false,
    bool floatingMode = false,
    bool showOnAllDisplays = true,
    bool isPreview = false,
    String breakTheme = 'random',
    String? reminderType,
    Map<String, dynamic>? overlayData,
  }) async {
    final settings = sl<SettingsRepository>().currentSettings;
    overlayData = {
      'reduceMotion': settings.reduceMotion || !settings.enableAnimations,
      'experience': settings.experience.toMap(),
      'largeText': settings.largeOverlayText,
      ...?overlayData,
    };
    if (_isOverlayVisible && _currentOverlayType == type && !isPreview) {
      if (type != OverlayType.clockPreview) {
        final args = <String, dynamic>{
          'type': type.name,
          'overlayType': type.name,
          'showOnAllDisplays': showOnAllDisplays,
          'isPreview': isPreview,
          'theme': breakTheme,
          'isTransparent':
              type == OverlayType.quickReminder ||
              type == OverlayType.preBreakWarning,
          'ignoreMouseEvents':
              type == OverlayType.quickReminder ||
              type == OverlayType.preBreakWarning,
          ...overlayData,
        };
        if (reminderType != null) args['reminderType'] = reminderType;
        await NativeBridge.showOverlay(OverlayArgs(args: args));
      }
      return;
    }

    if (!_isOverlayVisible) {
      // Captured only for the first overlay so a stacked overlay does not overwrite it.
      _wasMainVisibleBeforeOverlay =
          type == OverlayType.breakScreen && (await windowManager.isVisible());
      _logger.info(
        'Main window visibility status before overlay: $_wasMainVisibleBeforeOverlay',
      );
    }

    try {
      _logger.info('Showing global overlay: $type (Preview: $isPreview)');

      await windowManager.setIgnoreMouseEvents(false);

      if (type != OverlayType.clockPreview) {
        if (Platform.isWindows || Platform.isLinux) {
          final args = <String, dynamic>{
            'type': type.name,
            'overlayType': type.name,
            'showOnAllDisplays': showOnAllDisplays,
            'isPreview': isPreview,
            'theme': breakTheme,
            'isTransparent':
                type == OverlayType.quickReminder ||
                type == OverlayType.preBreakWarning,
            'ignoreMouseEvents':
                type == OverlayType.quickReminder ||
                type == OverlayType.preBreakWarning,
            ...overlayData,
          };
          if (reminderType != null) args['reminderType'] = reminderType;
          await NativeBridge.showOverlay(OverlayArgs(args: args));

          if (type == OverlayType.breakScreen) {
            // Hide the main window shortly after the overlay appears so it does not flash or stay behind.
            Future.delayed(const Duration(milliseconds: 200), () {
              if (!isPreview) {
                windowManager.hide();
              }
            });
          }
        } else if (Platform.isMacOS) {
          final args = <String, dynamic>{
            'type': type.name,
            'overlayType': type.name,
            'showOnAllDisplays': showOnAllDisplays,
            'isPreview': isPreview,
            'theme': breakTheme,
            'isTransparent':
                type == OverlayType.quickReminder ||
                type == OverlayType.preBreakWarning,
            'ignoreMouseEvents':
                type == OverlayType.quickReminder ||
                type == OverlayType.preBreakWarning,
            ...overlayData,
          };
          if (reminderType != null) args['reminderType'] = reminderType;
          await NativeBridge.showOverlay(OverlayArgs(args: args));
          if (strictMode && type == OverlayType.breakScreen && !isPreview) {
            await NativeBridge.setPresentationOptions(
              hideDock: true,
              hideMenu: true,
            );
          }

          if (type == OverlayType.breakScreen) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (!isPreview) {
                windowManager.hide();
              }
            });
          }
        }
      } else {
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

  /// Closes any overlay and brings the main window back; skipped if the app was in the background before the overlay unless [forceShow].
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
      } else if (Platform.isLinux) {
        await NativeBridge.hideOverlay(restoreMainWindow: true);
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

  /// Hides the overlay and resets window state (level, dock/menu bar, size); state is cleared even if a step throws.
  Future<void> hideOverlay() async {
    if (!_isOverlayVisible) {
      return;
    }

    try {
      _logger.info('Hiding overlay and resetting window state');

      if (Platform.isWindows) {
        try {
          await _windowsChannel.invokeMethod('resetToNormal');
        } catch (e, st) {
          ErrorHandler().handleError(e, st);
        }
      } else if (Platform.isLinux) {
        try {
          await NativeBridge.hideOverlay(
            restoreMainWindow: _wasMainVisibleBeforeOverlay,
          );
        } catch (e, st) {
          ErrorHandler().handleError(e, st);
        }
      } else if (Platform.isMacOS) {
        try {
          await NativeBridge.hideOverlay(
            restoreMainWindow: _wasMainVisibleBeforeOverlay,
          );
        } catch (e, st) {
          ErrorHandler().handleError(e, st);
        }
        try {
          await NativeBridge.setPresentationOptions(
            hideDock: false,
            hideMenu: false,
          );
        } catch (e, st) {
          ErrorHandler().handleError(e, st);
        }
      }

      await windowManager.setAlwaysOnTop(false);
      await windowManager.setFullScreen(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.setBackgroundColor(
        Platform.isWindows ? AppTheme.sidebarBackground : Colors.transparent,
      );

      _isOverlayVisible = false;
      _currentOverlayType = null;
      notifyListeners();

      if (_wasMainVisibleBeforeOverlay) {
        await windowManager.setIgnoreMouseEvents(false);
        await windowManager.setSize(const Size(1100, 750));
      }
      _wasMainVisibleBeforeOverlay = false;

      _logger.info('Overlay hidden successfully');
    } catch (e) {
      _logger.error('Failed to hide overlay: $e');

      try {
        _isOverlayVisible = false;
        _currentOverlayType = null;
      } catch (e, st) {
        ErrorHandler().handleError(e, st);
      }
      notifyListeners();
    }
  }

  bool get isOverlayVisible => _isOverlayVisible;

  OverlayType? get currentOverlayType => _currentOverlayType;

  /// Force-clears overlay state without restoring the main window.
  Future<void> reset() async {
    _isOverlayVisible = false;
    _currentOverlayType = null;
    if (Platform.isWindows) {
      await _windowsChannel.invokeMethod('resetToNormal');
    } else if (Platform.isLinux) {
      await NativeBridge.hideOverlay();
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

// quickReminder and preBreakWarning are transparent and click-through; breakScreen is the blocking full overlay.
enum OverlayType { preBreakWarning, breakScreen, clockPreview, quickReminder }
