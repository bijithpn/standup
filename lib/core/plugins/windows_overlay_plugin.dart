import 'dart:io';
import 'package:flutter/services.dart';

/// Windows-specific overlay window plugin for native window manipulation
class WindowsOverlayPlugin {
  static const MethodChannel _channel = MethodChannel(
    'com.breakmate/overlay_window',
  );

  /// Configure the window as a full-screen overlay (always on top, no borders)
  static Future<void> configureAsOverlay() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('configureAsOverlay');
    } on PlatformException catch (e) {
      throw Exception('Failed to configure overlay: ${e.message}');
    }
  }

  /// Reset the window to normal state
  static Future<void> resetToNormal() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('resetToNormal');
    } on PlatformException catch (e) {
      throw Exception('Failed to reset window: ${e.message}');
    }
  }

  /// Set window transparency (opacity 0.0 - 1.0)
  static Future<void> setTransparency(double opacity) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setTransparency', {'opacity': opacity});
    } on PlatformException catch (e) {
      throw Exception('Failed to set transparency: ${e.message}');
    }
  }

  /// Set window to ignore mouse events (click-through)
  static Future<void> setIgnoreMouseEvents(bool ignore) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setIgnoreMouseEvents', {'ignore': ignore});
    } on PlatformException catch (e) {
      throw Exception('Failed to set mouse events: ${e.message}');
    }
  }
}
