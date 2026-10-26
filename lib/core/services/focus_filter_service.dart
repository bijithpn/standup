import 'dart:async';
import 'package:breakmate/core/native/focus_mode_service.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/utils/logger.dart';

/// Service managing macOS Focus Mode & Do Not Disturb state, leveraging
/// Apple's modern Intents framework (INFocusStatusCenter) on macOS 12+
/// matching DeskRest's FocusFilterService implementation.
class FocusFilterService {
  final FocusModeService _focusModeService;
  final SmartDetectionService _smartDetection;
  final AppLogger _logger = AppLogger();

  final _focusStatusController = StreamController<bool>.broadcast();
  Stream<bool> get focusStream => _focusStatusController.stream;

  bool _isFocusActive = false;
  bool get isFocusActive => _isFocusActive;

  StreamSubscription? _focusSub;
  StreamSubscription? _smartSub;

  FocusFilterService({
    FocusModeService? focusModeService,
    required SmartDetectionService smartDetection,
  }) : _focusModeService = focusModeService ?? FocusModeService(),
       _smartDetection = smartDetection {
    _init();
  }

  void _init() {
    // 1. Listen to dedicated FocusModeService (com.breakmate/focus_mode)
    _focusSub = _focusModeService.isFocusModeActiveStream.listen(
      _updateFocusState,
      onError: (err) {
        _logger.error('FocusFilterService error from focusModeService: $err');
      },
    );

    // 2. Cross-correlate with SmartDetectionService (com.breakmate/smart_detection_events)
    _smartSub = _smartDetection.stateStream.listen(
      (state) {
        if (state.isFocusModeActive != _isFocusActive) {
          _updateFocusState(state.isFocusModeActive);
        }
      },
      onError: (err) {
        _logger.error('FocusFilterService error from smartDetection: $err');
      },
    );
  }

  void _updateFocusState(bool active) {
    if (_isFocusActive == active) return;
    _isFocusActive = active;
    _logger.info(
      'FocusFilterService: Focus status changed -> isFocused: $active',
    );
    _focusStatusController.add(active);
  }

  /// Determines if a break reminder or fullscreen break overlay should be
  /// suppressed or delayed based on the user's focus mode preferences.
  bool shouldSuppressBreak({bool pauseOnFocusMode = true}) {
    if (!pauseOnFocusMode) return false;
    return _isFocusActive;
  }

  void dispose() {
    _focusSub?.cancel();
    _smartSub?.cancel();
    _focusStatusController.close();
  }
}
