import 'dart:async';
import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';

/// Detects video calls, meetings, and macOS Focus/DND to pause reminders.
class SmartDetectionService {
  static const _channel = MethodChannel('com.breakmate.macos/bridge');
  final AppLogger _logger = AppLogger();

  bool _isVideoCallActive = false;
  bool _isFocusModeActive = false;
  bool _loggedDetectionUnavailable = false;

  Timer? _pollTimer;

  bool get shouldPauseReminders => _isVideoCallActive || _isFocusModeActive;
  bool get isVideoCallActive => _isVideoCallActive;
  bool get isFocusModeActive => _isFocusModeActive;

  void start() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
    _logger.info('SmartDetectionService started');
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    await Future.wait([
      _checkVideoCall(),
      _checkFocusMode(),
    ]);
  }

  Future<void> _checkVideoCall() async {
    try {
      final String? frontApp =
          await _channel.invokeMethod<String>('getFrontmostApp');
      if (frontApp == null) return;

      const videoCallApps = [
        'zoom.us',
        'com.microsoft.teams',
        'com.google.chrome', // Meet runs in Chrome
        'us.zoom.xos',
        'com.apple.facetime',
        'com.slack.slack',
        'com.cisco.webex.meetings',
        'com.loom.desktop',
      ];

      final wasActive = _isVideoCallActive;
      _isVideoCallActive = videoCallApps.any(
        (app) => frontApp.toLowerCase().contains(app.toLowerCase()),
      );

      if (wasActive != _isVideoCallActive) {
        _logger.info(_isVideoCallActive
            ? 'Video call detected: $frontApp'
            : 'Video call ended');
      }
    } on MissingPluginException {
      // Channel method not implemented — fail silently
    } catch (e) {
      if (!_loggedDetectionUnavailable) {
        _logger.error('Video call detection unavailable: $e');
        _loggedDetectionUnavailable = true;
      }
    }
  }

  Future<void> _checkFocusMode() async {
    try {
      final bool? active =
          await _channel.invokeMethod<bool>('isFocusModeActive');
      if (active == null) return;

      final wasActive = _isFocusModeActive;
      _isFocusModeActive = active;

      if (wasActive != _isFocusModeActive) {
        _logger.info(_isFocusModeActive
            ? 'Focus/DND mode active'
            : 'Focus/DND mode ended');
      }
    } on MissingPluginException {
      // Not implemented — fail silently
    } catch (e) {
      if (!_loggedDetectionUnavailable) {
        _logger.error('Focus mode detection unavailable: $e');
        _loggedDetectionUnavailable = true;
      }
    }
  }

  void dispose() {
    stop();
  }
}
