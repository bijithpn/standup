import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';

const _ipcChannel = MethodChannel('com.breakmate/ipc');

class IpcBridge {
  IpcBridge._();
  static final IpcBridge instance = IpcBridge._();
  final _logger = AppLogger();

  void setEventHandler(void Function(String event, Map<String, dynamic> data) handler) {
    _ipcChannel.setMethodCallHandler((call) async {
      _logger.info('IPC event: ${call.method}');
      try {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final data = args?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
        handler(call.method, data);
      } catch (e) {
        _logger.error('IPC handler error: $e');
      }
    });
  }

  Future<void> sendEvent(String event, [Map<String, dynamic>? data]) async {
    try {
      await _ipcChannel.invokeMethod('sendEvent', {
        'event': event,
        'data': data ?? {},
      });
    } catch (e) {
      _logger.error('Failed to send IPC event $event: $e');
    }
  }

  Future<void> notifyCompanionStateChanged(String state) async {
    await sendEvent('companion.stateChanged', {'state': state});
  }

  Future<void> notifyCompanionPosition({required double x, required double y}) async {
    await sendEvent('companion.positionChanged', {'x': x, 'y': y});
  }

  Future<void> notifyTimerStateChanged(String state, {
    required int countdownSeconds,
    required int workElapsedSeconds,
    int? targetEndTime,
  }) async {
    await sendEvent('timer.stateChanged', {
      'state': state,
      'countdownSeconds': countdownSeconds,
      'workElapsedSeconds': workElapsedSeconds,
      'targetEndTime': targetEndTime,
    });
  }

  Future<void> notifyMeetingDetected(bool isActive, {String? bundleId}) async {
    await sendEvent('detection.meeting', {
      'isActive': isActive,
      'bundleId': bundleId ?? '',
    });
  }

  Future<void> notifyFocusMode(bool isActive) async {
    await sendEvent('detection.focusMode', {'isActive': isActive});
  }

  Future<void> notifyTrayAction(String action) async {
    await sendEvent('tray.action', {'action': action});
  }
}
