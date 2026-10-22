import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/core/ipc/ipc_maps.dart';

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
        final data = args == null ? <String, dynamic>{} : stringKeyedMap(args);
        handler(call.method, data);
      } catch (e) {
        _logger.error('IPC handler error: $e');
      }
    });
  }

  /// Binds a handler that processes typed IPC events.
  void setTypedEventHandler(void Function(IpcEvent event) handler) {
    setEventHandler((event, data) {
      handler(IpcEvent.parse(event, data));
    });
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
    await dispatch(IpcEvent.companionStateChanged(state: state));
  }

  Future<void> notifyCompanionPosition({
    required double x,
    required double y,
  }) async {
    await dispatch(IpcEvent.companionPositionChanged(x: x, y: y));
  }

  Future<void> notifyTimerStateChanged(
    String state, {
    required int countdownSeconds,
    required int workElapsedSeconds,
    int? targetEndTime,
    int? totalWorkTodaySeconds,
  }) async {
    await dispatch(
      IpcEvent.timerStateChanged(
        stateName: state,
        countdownSeconds: countdownSeconds,
        workElapsedSeconds: workElapsedSeconds,
        targetEndTime: targetEndTime,
        totalWorkTodaySeconds: totalWorkTodaySeconds,
      ),
    );
  }

  Future<void> notifyMeetingDetected(bool isActive, {String? bundleId}) async {
    await dispatch(
      IpcEvent.meetingDetected(isActive: isActive, bundleId: bundleId ?? ''),
    );
  }

  Future<void> notifyFocusMode(bool isActive) async {
    await dispatch(IpcEvent.focusMode(isActive: isActive));
  }

  Future<void> notifyTrayAction(String action) async {
    await dispatch(IpcEvent.trayAction(action: action));
  }
}
