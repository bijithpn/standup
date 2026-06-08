import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';

const _ipcChannel = MethodChannel('com.breakmate/ipc');

class IpcBridge {
  IpcBridge._();
  static final IpcBridge instance = IpcBridge._();
  final _logger = AppLogger();
  final Map<String, DateTime> _lastSuccessfulEventByName = {};

  DateTime? lastSuccessfulEvent(String eventName) {
    return _lastSuccessfulEventByName[eventName];
  }

  void setEventHandler(
    void Function(String event, Map<String, dynamic> data) handler,
  ) {
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

  /// Preferred entry point for IPC consumers.
  ///
  /// This keeps validation in [IpcEvent.parse] and prevents callers from
  /// spreading native map parsing across UI and service layers.
  void setTypedEventHandler(void Function(IpcEvent event) handler) {
    setEventHandler((event, data) {
      handler(IpcEvent.parse(event, data));
    });
  }

  // TODO: Migrate the convenience notify methods to build typed
  // IpcEvent instances and call dispatch(), then keep sendEvent() only for
  // temporary native compatibility.
  Future<void> sendEvent(String event, [Map<String, dynamic>? data]) async {
    int retries = 3;
    while (retries > 0) {
      try {
        await _ipcChannel.invokeMethod('sendEvent', {
          'event': event,
          'data': data ?? {},
        });
        _lastSuccessfulEventByName[event] = DateTime.now();
        return;
      } catch (e) {
        retries--;
        if (retries == 0) {
          _logger.error('Failed to send IPC event $event: $e');
        } else {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    }
  }

  Future<void> dispatch(IpcEvent event) async {
    int retries = 3;
    while (retries > 0) {
      try {
        await _ipcChannel.invokeMethod('sendEvent', {
          'event': event.eventName,
          'data': event.payload,
        });
        _lastSuccessfulEventByName[event.eventName] = DateTime.now();
        return;
      } catch (e) {
        retries--;
        if (retries == 0) {
          _logger.error(
            'Failed to dispatch typed IPC event ${event.eventName}: $e',
          );
        } else {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    }
  }

  Future<void> notifyCompanionStateChanged(String state) async {
    await sendEvent('companion.stateChanged', {'state': state});
  }

  Future<void> notifyCompanionPosition({
    required double x,
    required double y,
  }) async {
    await sendEvent('companion.positionChanged', {'x': x, 'y': y});
  }

  Future<void> notifyTimerStateChanged(
    String state, {
    required int countdownSeconds,
    required int workElapsedSeconds,
    int? targetEndTime,
    int? totalWorkTodaySeconds,
  }) async {
    await sendEvent(IpcEventNames.timerStateChanged, {
      'state': state,
      'countdownSeconds': countdownSeconds,
      'workElapsedSeconds': workElapsedSeconds,
      'targetEndTime': targetEndTime,
      'totalWorkTodaySeconds': totalWorkTodaySeconds,
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
