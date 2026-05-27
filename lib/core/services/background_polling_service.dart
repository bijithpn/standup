import 'dart:async';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/utils/logger.dart';

/// Top-level entry point function for the background Dart Isolate.
void _backgroundPollingEntry(Map<String, dynamic> initialData) {
  final RootIsolateToken token = initialData['token'] as RootIsolateToken;
  final SendPort sendPort = initialData['sendPort'] as SendPort;
  int idleThresholdMinutes = initialData['idleThresholdMinutes'] as int? ?? 3;

  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  final ReceivePort commandPort = ReceivePort();
  sendPort.send(commandPort.sendPort);

  bool isIdle = false;
  bool isVideoCallActive = false;
  bool isFocusModeActive = false;

  Timer? idleTimer;
  Timer? smartTimer;

  const bridgeChannel = MethodChannel('com.breakmate.macos/bridge');

  commandPort.listen((message) {
    if (message is Map<String, dynamic>) {
      final command = message['command'] as String?;
      if (command == 'setIdleThreshold') {
        idleThresholdMinutes = message['minutes'] as int? ?? idleThresholdMinutes;
      } else if (command == 'stop') {
        idleTimer?.cancel();
        smartTimer?.cancel();
        commandPort.close();
      }
    }
  });

  // 1. Idle status polling (every 5 seconds)
  idleTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
    try {
      final double? idleSeconds = await bridgeChannel.invokeMethod<double>('getIdleTime');
      if (idleSeconds != null) {
        final thresholdSeconds = idleThresholdMinutes * 60;
        final newIsIdle = idleSeconds >= thresholdSeconds;

        if (newIsIdle != isIdle) {
          isIdle = newIsIdle;
          sendPort.send({
            'type': 'idleChanged',
            'isIdle': isIdle,
            'idleSeconds': idleSeconds,
          });
        }
      }
    } catch (_) {
      // Fail silently in background thread
    }
  });

  // 2. Video calls & Focus Mode polling (every 10 seconds)
  smartTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
    try {
      // Check Video Call
      final String? frontApp = await bridgeChannel.invokeMethod<String>('getFrontmostApp');
      bool newVideoCallActive = false;
      if (frontApp != null) {
        const videoCallApps = [
          'zoom.us',
          'com.microsoft.teams',
          'com.google.chrome',
          'us.zoom.xos',
          'com.apple.facetime',
          'com.slack.slack',
          'com.cisco.webex.meetings',
          'com.loom.desktop',
        ];
        newVideoCallActive = videoCallApps.any(
          (app) => frontApp.toLowerCase().contains(app.toLowerCase()),
        );
      }

      // Check Focus Mode
      final bool? activeFocus = await bridgeChannel.invokeMethod<bool>('isFocusModeActive');
      final newFocusActive = activeFocus ?? false;

      if (newVideoCallActive != isVideoCallActive || newFocusActive != isFocusModeActive) {
        isVideoCallActive = newVideoCallActive;
        isFocusModeActive = newFocusActive;
        sendPort.send({
          'type': 'smartDetectionChanged',
          'isVideoCallActive': isVideoCallActive,
          'isFocusModeActive': isFocusModeActive,
          'frontApp': frontApp,
        });
      }
    } catch (_) {
      // Fail silently in background thread
    }
  });
}

/// Centralized service to spawn a single background Dart isolate and manage OS-level MethodChannel polling.
class BackgroundPollingService {
  static final BackgroundPollingService instance = BackgroundPollingService._();
  BackgroundPollingService._();

  final AppLogger _logger = AppLogger();
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;

  bool _isRunning = false;

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    _logger.info('Starting BackgroundPollingService...');

    _receivePort = ReceivePort();
    final token = RootIsolateToken.instance;
    if (token == null) {
      _logger.error('RootIsolateToken is null. Cannot start background isolate.');
      _isRunning = false;
      return;
    }

    try {
      _isolate = await Isolate.spawn(
        _backgroundPollingEntry,
        {
          'token': token,
          'sendPort': _receivePort!.sendPort,
          'idleThresholdMinutes': sl<SettingsRepository>().currentSettings.pauseTimerAfterMinutes,
        },
      );

      _receivePort!.listen((message) {
        if (message is SendPort) {
          _sendPort = message;
        } else if (message is Map<String, dynamic>) {
          final type = message['type'] as String?;
          if (type == 'idleChanged') {
            final isIdle = message['isIdle'] as bool;
            final idleSeconds = (message['idleSeconds'] as num).toDouble();
            try {
              sl<ActivityMonitor>().updateIdleStatus(isIdle, idleSeconds);
            } catch (_) {}
          } else if (type == 'smartDetectionChanged') {
            final isVideoCallActive = message['isVideoCallActive'] as bool;
            final isFocusModeActive = message['isFocusModeActive'] as bool;
            final frontApp = message['frontApp'] as String?;
            try {
              sl<SmartDetectionService>().updateDetectionStatus(isVideoCallActive, isFocusModeActive, frontApp);
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      _logger.error('Failed to spawn background polling isolate: $e');
      _isRunning = false;
    }
  }

  void updateIdleThreshold(int minutes) {
    if (!_isRunning) return;
    _sendPort?.send({
      'command': 'setIdleThreshold',
      'minutes': minutes,
    });
  }

  void stop() {
    if (!_isRunning) return;
    _isRunning = false;

    _sendPort?.send({'command': 'stop'});
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.beforeNextEvent);

    _receivePort = null;
    _sendPort = null;
    _isolate = null;
    _logger.info('BackgroundPollingService stopped.');
  }
}
