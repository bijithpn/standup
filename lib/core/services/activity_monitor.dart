import 'dart:async';
import 'dart:io';

import 'package:standup/core/constants/app_constants.dart';
import 'package:standup/core/errors/app_exception.dart';
import 'package:standup/core/errors/error_handler.dart';
import 'package:standup/core/utils/logger.dart';

typedef ActivityCallback = void Function(bool isActive);

class ActivityMonitor {
  final ErrorHandler _errorHandler = ErrorHandler();
  final AppLogger _logger = AppLogger();

  Timer? _pollTimer;
  DateTime _lastActivityTime = DateTime.now();
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
    _lastActivityTime = DateTime.now();
    _isIdle = false;

    // Poll for idle time every 30 seconds using macOS ioreg
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkIdleStatus(),
    );

    _logger.info('Activity monitor started');
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _logger.info('Activity monitor stopped');
  }

  // Uses macOS ioreg to check HIDIdleTime (keyboard + mouse idle)
  Future<void> _checkIdleStatus() async {
    await _errorHandler.guard(
      action: () async {
        final result = await Process.run('ioreg', [
          '-c',
          'IOHIDSystem',
        ]);

        if (result.exitCode != 0) return;

        final output = result.stdout.toString();
        final idleMatch = RegExp(r'"HIDIdleTime"\s*=\s*(\d+)').firstMatch(output);
        if (idleMatch == null) return;

        final idleNanos = int.parse(idleMatch.group(1)!);
        final idleSeconds = idleNanos ~/ 1000000000;
        final thresholdSeconds = _idleThresholdMinutes * 60;

        final wasIdle = _isIdle;
        _isIdle = idleSeconds >= thresholdSeconds;

        if (!_isIdle) {
          _lastActivityTime = DateTime.now();
        }

        if (wasIdle != _isIdle) {
          _logger.info(_isIdle ? 'User went idle' : 'User activity resumed');
          _onActivityChanged?.call(!_isIdle);
        }
      },
      errorType: ErrorType.activityMonitor,
      retry: false,
    );
  }

  bool get isIdle => _isIdle;
  DateTime get lastActivityTime => _lastActivityTime;

  void dispose() {
    stop();
  }
}
