import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/core/services/notification_service.dart';
import 'package:breakmate/app/dependency_injection.dart';

class AwayBreakService {
  static final AwayBreakService instance = AwayBreakService._();
  AwayBreakService._();

  final AppLogger _logger = AppLogger();
  DateTime? _idleStartTime;
  bool _isCurrentlyAway = false;
  static const int minAwayThresholdMinutes = 4;

  void handleIdleTimeUpdate(double idleSeconds) {
    final idleMinutes = idleSeconds / 60.0;

    if (idleMinutes >= minAwayThresholdMinutes && !_isCurrentlyAway) {
      _isCurrentlyAway = true;
      _idleStartTime = DateTime.now().subtract(
        Duration(seconds: idleSeconds.toInt()),
      );
      _logger.info('User stepped away. Idle tracking started.');
    } else if (idleMinutes < 0.5 && _isCurrentlyAway) {
      // User just returned from being away!
      _isCurrentlyAway = false;
      final awayDuration = DateTime.now().difference(
        _idleStartTime ?? DateTime.now(),
      );
      final minutes = awayDuration.inMinutes;

      if (minutes >= minAwayThresholdMinutes) {
        _logger.info('User returned after $minutes minutes away.');
        _promptLogAwayBreak(minutes);
      }
      _idleStartTime = null;
    }
  }

  void _promptLogAwayBreak(int minutesAway) {
    try {
      // Auto-log break in history
      sl<BreakHistoryService>().recordBreak(
        time: DateTime.now(),
        completed: true,
      );
      sl<NotificationService>().showReminder(
        message: 'Logged $minutesAway min away as a completed break!',
      );
    } catch (e) {
      _logger.error('Failed to log away break: $e');
    }
  }
}
