import 'dart:async';
import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/native/macos_bridge.dart';
import 'package:standup/core/utils/logger.dart';

typedef ActivityCallback = void Function(bool isActive);

class ActivityMonitor {
  final AppLogger _logger = AppLogger();

  Timer? _pollTimer;
  bool _isIdle = false;
  ActivityCallback? _onActivityChanged;

  int _idleThresholdMinutes = AppConstants.idleThresholdMinutes;

  void setIdleThreshold(int minutes) {
    _idleThresholdMinutes = minutes;
  }

  void setActivityCallback(ActivityCallback callback) {
    _onActivityChanged = callback;
  }

  void start() {
    _isIdle = false;

    // Poll for idle time every 5 seconds for more responsive tracking
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkIdleStatus(),
    );

    _logger.info('Activity monitor started using MacOSBridge');
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _logger.info('Activity monitor stopped');
  }

  Future<void> _checkIdleStatus() async {
    try {
      final idleSeconds = await MacOSBridge.getIdleTime();
      final thresholdSeconds = _idleThresholdMinutes * 60;

      final wasIdle = _isIdle;
      _isIdle = idleSeconds >= thresholdSeconds;

      if (wasIdle != _isIdle) {
        _logger.info(_isIdle ? 'User went idle ($idleSeconds s)' : 'User activity resumed');
        _onActivityChanged?.call(!_isIdle);
      }
    } catch (e) {
      _logger.error('Failed to check idle status: $e');
    }
  }

  bool get isIdle => _isIdle;

  void dispose() {
    stop();
  }
}
