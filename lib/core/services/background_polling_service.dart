import 'dart:async';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/smart_detection_service.dart';
import 'package:breakmate/core/services/meeting_url_matcher.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/core/errors/error_handler.dart';

// Isolate entry: polls front app/meeting URL (10s). Platform channels are not available here, so calls are proxied to the main isolate.
void _backgroundPollingEntry(Map<String, dynamic> initialData) {
  final SendPort sendPort = initialData['sendPort'] as SendPort;

  final ReceivePort commandPort = ReceivePort();
  sendPort.send(commandPort.sendPort);

  bool isVideoCallActive = false;

  Timer? smartTimer;

  int nextRequestId = 0;
  final Map<int, Completer<dynamic>> pendingRequests = {};

  Future<dynamic> invokeMethodProxy(
    String method, [
    dynamic args,
    String channel = 'com.breakmate.desktop/bridge',
  ]) {
    final completer = Completer<dynamic>();
    final requestId = nextRequestId++;
    pendingRequests[requestId] = completer;

    sendPort.send({
      'type': 'invokeMethod',
      'id': requestId,
      'channel': channel,
      'method': method,
      'args': args,
    });

    return completer.future;
  }

  commandPort.listen((message) {
    if (message is Map<String, dynamic>) {
      final type = message['type'] as String?;
      if (type == 'invokeMethodResult') {
        final id = message['id'] as int;
        final completer = pendingRequests.remove(id);
        if (completer != null) {
          if (message.containsKey('error')) {
            completer.completeError(message['error']);
          } else {
            completer.complete(message['result']);
          }
        }
      } else {
        final command = message['command'] as String?;
        if (command == 'stop') {
          smartTimer?.cancel();
          for (final c in pendingRequests.values) {
            c.completeError('Isolate stopped');
          }
          pendingRequests.clear();
          commandPort.close();
        }
      }
    }
  });

  smartTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
    try {
      final String? frontApp =
          (await invokeMethodProxy('getFrontmostApp')) as String?;
      bool newVideoCallActive = false;
      if (frontApp != null) {
        // Bundle ids treated as a video call when frontmost; browsers are also checked by URL below.
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

      if (!newVideoCallActive) {
        try {
          final activeApp =
              (await invokeMethodProxy('getActiveApp', {
                    'includeUrl': true,
                  }, 'com.breakmate/app_tracking'))
                  as Map?;
          final url = activeApp?['url'] as String?;
          newVideoCallActive = MeetingUrlMatcher.isMeetingUrl(url);
        } catch (_) {}
      }

      if (newVideoCallActive != isVideoCallActive) {
        isVideoCallActive = newVideoCallActive;
        sendPort.send({
          'type': 'smartDetectionChanged',
          'isVideoCallActive': isVideoCallActive,
          'frontApp': frontApp,
        });
      }
    } catch (_) {}
  });
}

/// Runs meeting detection in a separate isolate and forwards results to SmartDetectionService (idle detection lives in ActivityMonitor).
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

    try {
      _isolate = await Isolate.spawn(_backgroundPollingEntry, {
        'sendPort': _receivePort!.sendPort,
      });

      _receivePort!.listen((message) {
        if (message is SendPort) {
          _sendPort = message;
        } else if (message is Map<String, dynamic>) {
          final type = message['type'] as String?;
          if (type == 'smartDetectionChanged') {
            final isVideoCallActive = message['isVideoCallActive'] as bool;
            final frontApp = message['frontApp'] as String?;
            try {
              sl<SmartDetectionService>().updateDetectionStatus(
                isVideoCallActive,
                frontApp,
              );
            } catch (e, st) {
              ErrorHandler().handleError(e, st);
            }
          } else if (type == 'invokeMethod') {
            final id = message['id'] as int;
            final method = message['method'] as String;
            final args = message['args'];
            final channel =
                message['channel'] as String? ?? 'com.breakmate.desktop/bridge';
            _handleInvokeMethodProxy(id, method, args, channel);
          }
        }
      });
    } catch (e) {
      _logger.error('Failed to spawn background polling isolate: $e');
      _isRunning = false;
    }
  }

  // Runs a platform-channel call on behalf of the isolate and sends back the result or error.
  void _handleInvokeMethodProxy(
    int id,
    String method,
    dynamic args,
    String channel,
  ) async {
    final bridgeChannel = MethodChannel(channel);
    try {
      final result = await bridgeChannel.invokeMethod(method, args);
      _sendPort?.send({
        'type': 'invokeMethodResult',
        'id': id,
        'result': result,
      });
    } catch (e) {
      _sendPort?.send({
        'type': 'invokeMethodResult',
        'id': id,
        'error': e.toString(),
      });
    }
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
