import 'package:breakmate/core/services/away_break_service.dart';
import 'package:breakmate/core/services/background_polling_service.dart';
import 'package:breakmate/core/utils/logger.dart';

typedef ActivityCallback = void Function(bool isActive);

class ActivityMonitor {
  final AppLogger _logger = AppLogger();

  bool _isIdle = false;
  ActivityCallback? _onActivityChanged;

  void setIdleThreshold(int minutes) {
    BackgroundPollingService.instance.updateIdleThreshold(minutes);
  }

  void setActivityCallback(ActivityCallback callback) {
    _onActivityChanged = callback;
  }

  void Function(double idleSeconds)? _onIdleSample;

  /// Called with the current idle time on every poll (a few seconds apart).
  void setIdleSampleCallback(void Function(double idleSeconds) callback) {
    _onIdleSample = callback;
  }

  void sampleIdle(double idleSeconds) => _onIdleSample?.call(idleSeconds);

  void start() {
    _isIdle = false;
    BackgroundPollingService.instance.start();
    _logger.info('Activity monitor started delegating to background isolate');
  }

  void stop() {
    _logger.info('Activity monitor stopped');
  }

  void updateIdleStatus(bool isIdle, double idleSeconds) {
    final wasIdle = _isIdle;
    _isIdle = isIdle;

    AwayBreakService.instance.handleIdleTimeUpdate(idleSeconds);

    if (wasIdle != _isIdle) {
      _logger.info(
        _isIdle ? 'User went idle ($idleSeconds s)' : 'User activity resumed',
      );
      _onActivityChanged?.call(!_isIdle);
    }
  }

  bool get isIdle => _isIdle;

  void dispose() {
    stop();
  }
}
