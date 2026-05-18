import 'dart:developer' as developer;

import 'package:flutter/services.dart';

class MacOSBridge {
  static const MethodChannel _channel = MethodChannel('com.breakmate.macos/bridge');
  static final Set<String> _loggedMissingMethods = {};

  /// Show the full-screen break overlay
  static Future<void> showOverlay() async {
    await _invokeSafely('showOverlay');
  }

  /// Hide the break overlay and return to normal window state
  static Future<void> hideOverlay() async {
    await _invokeSafely('hideOverlay');
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
