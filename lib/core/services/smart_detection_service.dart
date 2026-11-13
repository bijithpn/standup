import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:breakmate/core/services/background_polling_service.dart';
import 'package:breakmate/core/utils/logger.dart';

/// Snapshot from the native detector: mic/camera/meeting/video activity and whether breaks should pause.
class SmartDetectionState {
  final bool isMicrophoneActive;
  final bool isCameraActive;
  final bool isInMeeting;
  final bool isVideoPlaying;
  final bool shouldPauseBreaks;

  const SmartDetectionState({
    required this.isMicrophoneActive,
    required this.isCameraActive,
    required this.isInMeeting,
    required this.isVideoPlaying,
    required this.shouldPauseBreaks,
  });

  factory SmartDetectionState.fromMap(Map<dynamic, dynamic> map) {
    return SmartDetectionState(
      isMicrophoneActive: map['isMicrophoneActive'] as bool? ?? false,
      isCameraActive: map['isCameraActive'] as bool? ?? false,
      isInMeeting: map['isInMeeting'] as bool? ?? false,
      isVideoPlaying: map['isVideoPlaying'] as bool? ?? false,
      shouldPauseBreaks: map['shouldPauseBreaks'] as bool? ?? false,
    );
  }

  static const idle = SmartDetectionState(
    isMicrophoneActive: false,
    isCameraActive: false,
    isInMeeting: false,
    isVideoPlaying: false,
    shouldPauseBreaks: false,
  );
}

/// Listens to native meeting/video detection and exposes whether reminders should pause; falls back to isolate polling off macOS.
class SmartDetectionService {
  static const _eventChannel = EventChannel(
    'com.breakmate/smart_detection_events',
  );

  final AppLogger _logger = AppLogger();

  final _stateController = StreamController<SmartDetectionState>.broadcast();
  StreamSubscription<dynamic>? _subscription;
  SmartDetectionState _currentState = SmartDetectionState.idle;

  bool _isVideoCallActive = false;
  bool _isVideoPlaying = false;

  Stream<SmartDetectionState> get stateStream => _stateController.stream;
  SmartDetectionState get currentState => _currentState;

  bool get shouldPauseReminders => _isVideoCallActive || _isVideoPlaying;
  bool get isVideoCallActive => _isVideoCallActive;
  bool get isVideoPlaying => _isVideoPlaying;

  bool _usingPollingFallback = false;

  void start() {
    _usingPollingFallback = false;
    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      _onNativeState,
      onError: (Object err) {
        _logger.error('SmartDetection stream error: $err');

        // No native stream available: use the background isolate heuristics instead.
        if (!Platform.isMacOS && !_usingPollingFallback) {
          _usingPollingFallback = true;
          _subscription?.cancel();
          _subscription = null;
          BackgroundPollingService.instance.start();
          _logger.info(
            'SmartDetectionService falling back to background isolate',
          );
        }
      },
    );
    _logger.info('SmartDetectionService connected to native detector');
  }

  void _onNativeState(dynamic data) {
    if (data is! Map) return;
    final state = SmartDetectionState.fromMap(data);
    _currentState = state;
    _isVideoCallActive = state.isInMeeting;
    _isVideoPlaying = state.isVideoPlaying;
    _stateController.add(state);

    if (state.shouldPauseBreaks) {
      _logger.info(
        'SmartDetection: Breaks paused (Meeting: ${state.isInMeeting}, Video: ${state.isVideoPlaying})',
      );
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    if (_usingPollingFallback) {
      BackgroundPollingService.instance.stop();
      _usingPollingFallback = false;
    }
    _logger.info('SmartDetectionService stopped');
  }

  /// Called by BackgroundPollingService when polling (not native events) changes the video-call state.
  void updateDetectionStatus(bool isVideoCallActive, String? frontApp) {
    final wasVideoCallActive = _isVideoCallActive;

    _isVideoCallActive = isVideoCallActive;

    if (wasVideoCallActive != _isVideoCallActive) {
      _logger.info(
        _isVideoCallActive
            ? 'Video call detected: $frontApp'
            : 'Video call ended',
      );
    }
  }

  void dispose() {
    stop();
    _stateController.close();
  }
}
