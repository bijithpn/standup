import 'package:flutter/services.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

enum TimerReturnChoice { continueSession, startOver }

/// Native dialog works even when the dashboard is closed.
class TimerReturnPrompt {
  static Future<TimerReturnChoice?> show(
    Duration remaining,
    Duration interval,
  ) async {
    final result =
        await const MethodChannel(
          'com.breakmate/native_enhancements',
        ).invokeMethod<String>('showTimerReturnPrompt', {
          'remainingSeconds': remaining.inSeconds,
          'intervalMinutes': interval.inMinutes,
          'theme': {
            'background': AppTheme.surfaceElevated.toARGB32(),
            'surface': AppTheme.surfaceCard.toARGB32(),
            'border': AppTheme.border.toARGB32(),
            'foreground': AppTheme.textPrimary.toARGB32(),
            'secondary': AppTheme.textSecondary.toARGB32(),
            'accent': AppTheme.accent.toARGB32(),
            'onAccent': AppTheme.onAccent.toARGB32(),
            'isDark': AppTheme.activePreset.isDark,
          },
        });
    return switch (result) {
      'continue' => TimerReturnChoice.continueSession,
      'restart' => TimerReturnChoice.startOver,
      _ => null,
    };
  }
}
