import 'package:breakmate/core/services/background_polling_service.dart';
import 'package:breakmate/core/utils/logger.dart';

/// Detects video calls, meetings, and macOS Focus/DND to pause reminders by delegating polling to a background isolate.
class SmartDetectionService {
  final AppLogger _logger = AppLogger();

  bool _isVideoCallActive = false;
  bool _isFocusModeActive = false;

  bool get shouldPauseReminders => _isVideoCallActive || _isFocusModeActive;
  bool get isVideoCallActive => _isVideoCallActive;
  bool get isFocusModeActive => _isFocusModeActive;

  void start() {
    BackgroundPollingService.instance.start();
    _logger.info(
      'SmartDetectionService started delegating to background isolate',
    );
  }

  void stop() {
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
