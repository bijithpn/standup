import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';

// Substrings matched against executable, bundle id and app name.
const Set<String> kKnownMeetingApps = {'zoom', 'teams', 'webex', 'slack'};

/// Reports whether a meeting app is in use; feeds the quiet-break logic and mirrors state to overlays over IPC.
class MeetingDetectionService {
  static const Duration _pollInterval = Duration(seconds: 5);

  final _channel = const EventChannel('com.breakmate/meeting_detection');
  final AppTrackingService _appTracking;

  MeetingDetectionService({AppTrackingService? appTracking})
    : _appTracking = appTracking ?? AppTrackingService();

  StreamSubscription? _subscription;
  Timer? _pollTimer;
  bool _isRunning = false;
  bool _isMeetingActive = false;
  bool? _lastPolled;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool get isMeetingActive => _isMeetingActive;

  Stream<bool> get isMeetingActiveStream => _controller.stream;

  /// macOS listens to a native event stream; Windows/Linux poll the active app.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _startNative();
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      _startPolling();
    }

    debugPrint('MeetingDetectionService started');
  }

  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _subscription?.cancel();
    _subscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _isMeetingActive = false;
    _lastPolled = null;
    debugPrint('MeetingDetectionService stopped');
  }

  void _startNative() {
    _subscription = _channel
        .receiveBroadcastStream()
        .map((event) {
          final data = Map<String, dynamic>.from(event);
          return data['isMeetingAppFrontmost'] as bool? ?? false;
        })
        .listen(
          _emit,
          onError: (error) {
            debugPrint('Error receiving meeting stream: $error');
          },
        );
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
    unawaited(_pollOnce());
  }

  @visibleForTesting
  Future<void> pollOnceForTest() => _pollOnce();

  // Only emits on change so listeners are not spammed every poll.
  Future<void> _pollOnce() async {
    try {
      final app = await _appTracking.getActiveApp();
      if (app == null) return;
      final active = _matchesKnownMeetingApp(app);

      if (active == _lastPolled) return;
      _lastPolled = active;
      _emit(active);
    } catch (e) {
      debugPrint('MeetingDetectionService poll error: $e');
    }
  }

  bool _matchesKnownMeetingApp(ActiveAppInfo app) {
    final exe = app.executableName.toLowerCase().replaceAll('.exe', '');
    final bundle = app.bundleId.toLowerCase();
    final name = app.name.toLowerCase();
    return kKnownMeetingApps.any(
      (known) =>
          exe.contains(known) || bundle.contains(known) || name.contains(known),
    );
  }

  // Also forwards to the other windows so the overlay can react to meetings.
  void _emit(bool isActive) {
    _isMeetingActive = isActive;
    _controller.add(isActive);
    IpcBridge.instance.notifyMeetingDetected(isActive);
  }
}
