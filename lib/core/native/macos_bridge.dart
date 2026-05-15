import 'package:flutter/services.dart';

class MacOSBridge {
  static const MethodChannel _channel = MethodChannel('com.breakmate.macos/bridge');

  /// Show the full-screen break overlay
  static Future<void> showOverlay() async {
    await _channel.invokeMethod('showOverlay');
  }

  /// Hide the break overlay and return to normal window state
  static Future<void> hideOverlay() async {
    await _channel.invokeMethod('hideOverlay');
  }

  /// Focus the application and un-minimize if needed
  static Future<void> focusApp() async {
    await _channel.invokeMethod('focusApp');
  }

  /// Set the window level (e.g., 'screenSaver', 'floating', 'normal')
  static Future<void> setWindowLevel(String level) async {
    await _channel.invokeMethod('setWindowLevel', {'level': level});
  }

  /// Set presentation options for the application
  static Future<void> setPresentationOptions({required bool hideDock, required bool hideMenu}) async {
    await _channel.invokeMethod('setPresentationOptions', {
      'hideDock': hideDock,
      'hideMenu': hideMenu,
    });
  }

  /// Get the system idle time in seconds
  static Future<double> getIdleTime() async {
    final double? idleTime = await _channel.invokeMethod<double>('getIdleTime');
    return idleTime ?? 0.0;
  }

  /// Get the current macOS appearance ('dark' or 'light')
  static Future<String> getAppearance() async {
    final String? appearance = await _channel.invokeMethod<String>('getAppearance');
    return appearance ?? 'light';
  }
}
