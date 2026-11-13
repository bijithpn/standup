import 'package:flutter/services.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';
import 'package:breakmate/core/ipc/ipc_maps.dart';

// Native-side channel that relays events between the main window and the overlay/companion windows.
const _ipcChannel = MethodChannel('com.breakmate/ipc');

/// Singleton wrapper over the IPC MethodChannel: sends typed [IpcEvent]s to other windows and receives theirs.
class IpcBridge {
  IpcBridge._();
  static final IpcBridge instance = IpcBridge._();
  final _logger = AppLogger();
  // Lets callers detect stale/silent peers by checking when an event last went through.
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

  void setTypedEventHandler(void Function(IpcEvent event) handler) {
    setEventHandler((event, data) {
      handler(IpcEvent.parse(event, data));
    });
  }

  /// Sends an event to the other window; retries up to 3 times (50ms apart) since the peer window may still be starting.
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

  Future<void> notifyTrayAction(String action) async {
    await dispatch(IpcEvent.trayAction(action: action));
  }
}
