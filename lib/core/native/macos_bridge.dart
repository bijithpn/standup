import 'dart:developer' as developer;

import 'package:flutter/services.dart';

class MacOSBridge {
  static const MethodChannel _channel = MethodChannel('com.breakmate.macos/bridge');
  static final Set<String> _loggedMissingMethods = {};

  /// Show the native multi-monitor overlay
  static Future<void> showOverlay([Map<String, dynamic>? args]) async {
    await _invokeSafely('showOverlay', args);
  }

  /// Hide the native multi-monitor overlay
  static Future<void> hideOverlay() async {
    await _invokeSafely('hideOverlay');
  }

  /// Skip the current break from the overlay and sync to main engine
  static Future<void> skipBreak() async {
    await _invokeSafely('skipBreak');
  }

  /// Set the visual effect (vibrancy) of the overlays
  static Future<void> setVisualEffect(String material) async {
    await _invokeSafely('setVisualEffect', {'material': material});
  }

  /// Focus the application and un-minimize if needed
  static Future<void> focusApp() async {
    await _invokeSafely('focusApp');
  }

  /// Set the window level (e.g., 'screenSaver', 'floating', 'normal')
  static Future<void> setWindowLevel(String level) async {
    await _invokeSafely('setWindowLevel', {'level': level});
  }

  /// Set presentation options for the application
  static Future<void> setPresentationOptions({required bool hideDock, required bool hideMenu}) async {
    await _invokeSafely('setPresentationOptions', {
      'hideDock': hideDock,
      'hideMenu': hideMenu,
    });
  }

  /// Get the system idle time in seconds
  static Future<double> getIdleTime() async {
    final double? idleTime = await _invokeSafely<double>('getIdleTime');
    return idleTime ?? 0.0;
  }

  /// Get the current macOS appearance ('dark' or 'light')
  static Future<String> getAppearance() async {
    final String? appearance = await _invokeSafely<String>('getAppearance');
    return appearance ?? 'light';
  }

  /// Set the overlay to ignore mouse events (click-through)
  static Future<void> setIgnoreMouseEvents(bool ignore) async {
    await _invokeSafely('setIgnoreMouseEvents', {'ignore': ignore});
  }

  /// Update data in all active overlay engines
  static Future<void> updateOverlayData(Map<String, dynamic> data) async {
    await _invokeSafely('updateOverlayData', data);
  }

  /// Spawns the native floating desktop companion window
  static Future<void> showCompanion(Map<String, dynamic> args) async {
    await _invokeSafely('showCompanion', args);
  }

  /// Closes the native floating desktop companion window
  static Future<void> hideCompanion() async {
    await _invokeSafely('hideCompanion');
  }

  /// Sets companion window click-through mode
  static Future<void> setCompanionClickThrough(bool ignore) async {
    await _invokeSafely('setCompanionClickThrough', {'ignore': ignore});
  }

  /// Updates companion scale and native dimensions
  static Future<void> updateCompanionScale(double scale) async {
    await _invokeSafely('updateCompanionScale', {'scale': scale});
  }

  /// Swaps companion theme dynamically
  static Future<void> updateCompanionTheme(String themeId) async {
    await _invokeSafely('updateCompanionTheme', {'themeId': themeId});
  }

  /// Updates companion display metadata.
  static Future<void> updateCompanionName(String petName) async {
    await _invokeSafely('updateCompanionName', {'petName': petName});
  }

  /// Triggers a dynamic behavioral animation state in the companion overlay
  static Future<void> triggerCompanionState(String stateName) async {
    await _invokeSafely('triggerCompanionState', {'state': stateName});
  }

  /// Sets wandering AI state in the companion overlay
  static Future<void> setCompanionWandering(bool enabled) async {
    await _invokeSafely('setCompanionWandering', {'enabled': enabled});
  }

  /// Sets follow mouse cursor state in the companion overlay
  static Future<void> setCompanionFollowMouse(bool enabled) async {
    await _invokeSafely('setCompanionFollowMouse', {'enabled': enabled});
  }

  static Future<T?> _invokeSafely<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      if (_loggedMissingMethods.add(method)) {
        developer.log(
          'macOS bridge method unavailable: $method',
          name: 'BreakMate',
        );
      }
      return null;
    } catch (e, stackTrace) {
      developer.log(
        'macOS bridge method failed: $method',
        name: 'BreakMate',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
