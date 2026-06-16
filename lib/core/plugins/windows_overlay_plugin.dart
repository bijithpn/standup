import 'dart:io';
import 'package:flutter/services.dart';
import 'package:breakmate/core/errors/app_exception.dart';

class WindowsOverlayPlugin {
  static const MethodChannel _channel = MethodChannel(
    'com.breakmate/overlay_window',
  );

  static Future<void> configureAsOverlay() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('configureAsOverlay');
    } on PlatformException catch (e) {
      throw AppException(
        type: AppErrorType.native,
        message: 'Failed to configure overlay: ${e.message}',
      );
    }
  }

  static Future<void> resetToNormal() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('resetToNormal');
    } on PlatformException catch (e) {
      throw AppException(
        type: AppErrorType.native,
        message: 'Failed to reset window: ${e.message}',
      );
    }
  }

  static Future<void> setTransparency(double opacity) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setTransparency', {'opacity': opacity});
    } on PlatformException catch (e) {
      throw AppException(
        type: AppErrorType.native,
        message: 'Failed to set transparency: ${e.message}',
      );
    }
  }

  static Future<void> setIgnoreMouseEvents(bool ignore) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setIgnoreMouseEvents', {'ignore': ignore});
    } on PlatformException catch (e) {
      throw AppException(
        type: AppErrorType.native,
        message: 'Failed to set mouse events: ${e.message}',
      );
    }
  }
}
