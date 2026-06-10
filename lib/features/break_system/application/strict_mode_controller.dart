import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';
import 'package:breakmate/core/native/focus_mode_service.dart';

class StrictModeController {
  final _overlayChannel = const MethodChannel('com.breakmate/overlay');
  final MeetingDetectionService _meetingService;
  final FocusModeService _focusService;

  bool _isStrictModeActive = false;
  bool _isInMeeting = false;
  bool _isFocusMode = false;

  StreamSubscription? _meetingSub;
  StreamSubscription? _focusSub;

  StrictModeController(this._meetingService, this._focusService) {
    _meetingSub = _meetingService.isMeetingActiveStream.listen((isActive) {
      _isInMeeting = isActive;
    });
    _focusSub = _focusService.isFocusModeActiveStream.listen((isActive) {
      _isFocusMode = isActive;
    });
  }

  bool get isStrictModeActive => _isStrictModeActive;
  bool get isInMeeting => _isInMeeting;
  bool get isFocusMode => _isFocusMode;

  Future<void> enableStrictMode() async {
    if (_isInMeeting) {
      debugPrint('Break suppressed: User is in a meeting.');
      return; // Meeting-aware suppression
    }

    _isStrictModeActive = true;
    debugPrint('Enabling Strict Mode overlay');

    try {
      await _overlayChannel.invokeMethod('setStrictMode', true);
    } catch (e) {
      debugPrint('Failed to set strict mode: $e');
    }
  }

  Future<void> disableStrictMode() async {
    _isStrictModeActive = false;
    debugPrint('Disabling Strict Mode overlay');
    try {
      await _overlayChannel.invokeMethod('setStrictMode', false);
    } catch (e) {
      debugPrint('Failed to disable strict mode: $e');
    }
  }

  void dispose() {
    _meetingSub?.cancel();
    _focusSub?.cancel();
  }
}
