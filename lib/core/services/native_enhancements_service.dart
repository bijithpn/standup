import 'dart:io';
import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/services/health_reminder_messages.dart';

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
    String? reminderType,
    int durationMs = 250,
    double opacity = 0.35,
    String colorHex = '#000000',
    bool dismissOnMouseMove = false,
    double textScale = 1,
    bool highContrast = false,
    bool reduceMotion = false,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('triggerFlashReminder', {
        'text': text,
        'title': HealthReminderMessages.heading(reminderType),
        'reminderType': reminderType ?? '',
        'durationMs': durationMs,
        'opacity': opacity,
        'colorHex': colorHex,
        'dismissOnMouseMove': dismissOnMouseMove,
        'textScale': textScale.clamp(1.0, 1.5),
        'highContrast': highContrast,
        'reduceMotion': reduceMotion,
      });
    } catch (e) {
      _logger.error('Failed to trigger flash reminder: $e');
    }
  }

  Future<void> dismissHealthReminder() async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('dismissHealthReminder');
    } catch (e) {
      _logger.error('Failed to dismiss health reminder: $e');
    }
  }

  Future<void> showToast({
    required String title,
    required String body,
    required bool sound,
  }) async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('showToast', {
        'title': title,
        'body': body,
        'sound': sound,
      });
    } catch (e) {
      _logger.error('Failed to show toast: $e');
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
