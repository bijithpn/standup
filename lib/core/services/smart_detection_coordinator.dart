import 'dart:async';
import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';

class SmartDetectionState {
  final bool isMicrophoneActive;
  final bool isCameraActive;
  final bool isInMeeting;
  final bool isVideoPlaying;
  final bool isFocusModeActive;
  final bool shouldPauseBreaks;

  const SmartDetectionState({
    required this.isMicrophoneActive,
    required this.isCameraActive,
    required this.isInMeeting,
    required this.isVideoPlaying,
    required this.isFocusModeActive,
    required this.shouldPauseBreaks,
  });

  factory SmartDetectionState.fromMap(Map<dynamic, dynamic> map) {
    return SmartDetectionState(
      isMicrophoneActive: map['isMicrophoneActive'] as bool? ?? false,
      isCameraActive: map['isCameraActive'] as bool? ?? false,
      isInMeeting: map['isInMeeting'] as bool? ?? false,
      isVideoPlaying: map['isVideoPlaying'] as bool? ?? false,
      isFocusModeActive: map['isFocusModeActive'] as bool? ?? false,
      shouldPauseBreaks: map['shouldPauseBreaks'] as bool? ?? false,
    );
  }

  static const idle = SmartDetectionState(
    isMicrophoneActive: false,
    isCameraActive: false,
    isInMeeting: false,
    isVideoPlaying: false,
    isFocusModeActive: false,
    shouldPauseBreaks: false,
  );
}

class SmartDetectionCoordinator {
  static final SmartDetectionCoordinator instance =
      SmartDetectionCoordinator._();
  SmartDetectionCoordinator._();

  static const _eventChannel = EventChannel(
    'com.breakmate/smart_detection_events',
  );
  final _logger = AppLogger();

  final _stateController = StreamController<SmartDetectionState>.broadcast();
  Stream<SmartDetectionState> get stateStream => _stateController.stream;
  SmartDetectionState _currentState = SmartDetectionState.idle;
  SmartDetectionState get currentState => _currentState;

  StreamSubscription? _subscription;

  void start() {
    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is Map) {
          final newState = SmartDetectionState.fromMap(data);
          _currentState = newState;
          _stateController.add(newState);

          if (newState.shouldPauseBreaks) {
            _logger.info(
              'SmartDetection: Breaks paused (Meeting: ${newState.isInMeeting}, Video: ${newState.isVideoPlaying}, Focus: ${newState.isFocusModeActive})',
            );
          }
        }
      },
      onError: (Object err) {
        _logger.error('SmartDetection stream error: $err');
      },
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stop();
    _stateController.close();
  }
}
