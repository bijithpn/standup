import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';

class StrictModeController {
  final _overlayChannel = const MethodChannel('com.breakmate/overlay');
  final MeetingDetectionService _meetingService;

  bool _isStrictModeActive = false;
  bool _isInMeeting = false;

  StreamSubscription? _meetingSub;

  StrictModeController(this._meetingService) {
    _meetingSub = _meetingService.isMeetingActiveStream.listen((isActive) {
      _isInMeeting = isActive;
    });
  }

  bool get isStrictModeActive => _isStrictModeActive;
  bool get isInMeeting => _isInMeeting;

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
  }
}
