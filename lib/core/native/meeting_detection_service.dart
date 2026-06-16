import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';

class MeetingDetectionService {
  final _channel = const EventChannel('com.breakmate/meeting_detection');
  StreamSubscription? _subscription;
  bool _isRunning = false;

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    if (defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }

    _subscription = _channel
        .receiveBroadcastStream()
        .map((event) {
          final data = Map<String, dynamic>.from(event);
          return data['isMeetingAppFrontmost'] as bool? ?? false;
        })
        .listen(
          (isActive) {
            IpcBridge.instance.notifyMeetingDetected(isActive);
          },
          onError: (error) {
            debugPrint('Error receiving meeting stream: $error');
          },
        );

    debugPrint('MeetingDetectionService started');
  }

  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _subscription?.cancel();
    _subscription = null;
    debugPrint('MeetingDetectionService stopped');
  }

  Stream<bool> get isMeetingActiveStream {
    if (defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.windows) {
      return const Stream<bool>.empty();
    }
    return _channel
        .receiveBroadcastStream()
        .map((event) {
          final data = Map<String, dynamic>.from(event);
          final isMeeting = data['isMeetingAppFrontmost'] as bool? ?? false;
          return isMeeting;
        })
        .handleError((error) {
          debugPrint('Error receiving meeting stream: $error');
          return false;
        });
  }
}
