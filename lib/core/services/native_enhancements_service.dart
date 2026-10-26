import 'dart:io';
import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';

class NativeEnhancementsService {
  static final NativeEnhancementsService instance =
      NativeEnhancementsService._();
  NativeEnhancementsService._();

  static const MethodChannel _channel = MethodChannel(
    'com.breakmate/native_enhancements',
  );
  final AppLogger _logger = AppLogger();

  static bool get _supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  Future<void> showCursorCountdown({int seconds = 15}) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('showCursorCountdown', {'seconds': seconds});
    } catch (e) {
      _logger.error('Failed to show cursor countdown: $e');
    }
  }

  Future<void> hideCursorCountdown() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('hideCursorCountdown');
    } catch (e) {
      _logger.error('Failed to hide cursor countdown: $e');
    }
  }

  Future<void> triggerFlashReminder({
    required String text,
    int durationMs = 250,
    double opacity = 0.35,
    String colorHex = '#000000',
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('triggerFlashReminder', {
        'text': text,
        'durationMs': durationMs,
        'opacity': opacity,
        'colorHex': colorHex,
      });
    } catch (e) {
      _logger.error('Failed to trigger flash reminder: $e');
    }
  }

  Future<void> preventDisplaySleep({
    String reason = 'BreakMate Break Active',
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('preventDisplaySleep', {'reason': reason});
    } catch (e) {
      _logger.error('Failed to prevent display sleep: $e');
    }
  }

  Future<void> releaseDisplaySleep() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('releaseDisplaySleep');
    } catch (e) {
      _logger.error('Failed to release display sleep: $e');
    }
  }
}
