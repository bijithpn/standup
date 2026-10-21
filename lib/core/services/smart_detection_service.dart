import 'dart:io';
import 'package:breakmate/core/services/background_polling_service.dart';
import 'package:breakmate/core/services/smart_detection_coordinator.dart';
import 'package:breakmate/core/utils/logger.dart';

/// Detects video calls, meetings, media playback, and macOS Focus/DND to pause reminders.
class SmartDetectionService {
  final AppLogger _logger = AppLogger();

  bool _isVideoCallActive = false;
  bool _isVideoPlaying = false;
  bool _isFocusModeActive = false;

  bool get shouldPauseReminders =>
      _isVideoCallActive || _isVideoPlaying || _isFocusModeActive;
  bool get isVideoCallActive => _isVideoCallActive;
  bool get isVideoPlaying => _isVideoPlaying;
  bool get isFocusModeActive => _isFocusModeActive;

  void start() {
    if (Platform.isMacOS) {
      SmartDetectionCoordinator.instance.start();
      SmartDetectionCoordinator.instance.stateStream.listen((state) {
        _isVideoCallActive = state.isInMeeting;
        _isVideoPlaying = state.isVideoPlaying;
        _isFocusModeActive = state.isFocusModeActive;
      });
      _logger.info('SmartDetectionService connected to NativeSmartDetector');
    } else {
      BackgroundPollingService.instance.start();
      _logger.info(
        'SmartDetectionService started delegating to background isolate',
      );
    }
  }

  void stop() {
    if (Platform.isMacOS) {
      SmartDetectionCoordinator.instance.stop();
    } else {
      BackgroundPollingService.instance.stop();
    }
    _logger.info('SmartDetectionService stopped');
  }

  void updateDetectionStatus(
    bool isVideoCallActive,
    bool isFocusModeActive,
    String? frontApp,
  ) {
    final wasVideoCallActive = _isVideoCallActive;
    final wasFocusModeActive = _isFocusModeActive;

    _isVideoCallActive = isVideoCallActive;
    _isFocusModeActive = isFocusModeActive;

    if (wasVideoCallActive != _isVideoCallActive) {
      _logger.info(
        _isVideoCallActive
            ? 'Video call detected: $frontApp'
            : 'Video call ended',
      );
    }

    if (wasFocusModeActive != _isFocusModeActive) {
      _logger.info(
        _isFocusModeActive ? 'Focus/DND mode active' : 'Focus/DND mode ended',
      );
    }
  }

  void dispose() {
    stop();
  }
}
