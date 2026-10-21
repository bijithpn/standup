import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';

/// Meeting-app identifiers used by the Windows polling fallback (see
/// [MeetingDetectionService._startPolling]). Matched case-insensitively
/// against [ActiveAppInfo.executableName] (".exe" stripped),
/// [ActiveAppInfo.bundleId], and [ActiveAppInfo.name] — deliberately the
/// same app set `MeetingDetectionBridge.swift` already hardcodes natively
/// for macOS (`us.zoom.xos`, `com.microsoft.teams`, etc.), just matched by
/// substring so both platforms' naming (`Zoom.exe` vs `us.zoom.xos`) hit
/// the same entries.
const Set<String> kKnownMeetingApps = {
  'zoom',
  'teams', // covers Microsoft Teams and the "ms-teams"/"msteams" exe names
  'webex', // covers WebexMta.exe / CiscoWebexStart.exe
  'slack',
};

/// Streams whether a known meeting app is currently frontmost.
///
/// - **macOS**: backed by `MeetingDetectionBridge.swift`, which pushes an
///   event on every app activation via `NSWorkspace` — instant, no polling.
/// - **Windows**: no native bridge exists for this yet, so this falls back
///   to polling [AppTrackingService.getActiveApp] — the same primitive
///   [AppUsageTracker] already polls every 10s — against
///   [kKnownMeetingApps]. Coarser than the macOS push channel (a few
///   seconds of lag instead of instant), but needs no new native C++ code,
///   the same tradeoff [PresentationDetectionService] already makes for
///   presentation detection.
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
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool get isMeetingActive => _isMeetingActive;

  Stream<bool> get isMeetingActiveStream => _controller.stream;

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _startNative();
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
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

  Future<void> _pollOnce() async {
    try {
      final app = await _appTracking.getActiveApp();
      if (app == null) return;
      _emit(_matchesKnownMeetingApp(app));
    } catch (e) {
      debugPrint('MeetingDetectionService poll error: $e');
    }
  }

  bool _matchesKnownMeetingApp(ActiveAppInfo app) {
    final exe = app.executableName.toLowerCase().replaceAll('.exe', '');
    final bundle = app.bundleId.toLowerCase();
    final name = app.name.toLowerCase();
    return kKnownMeetingApps.any(
      (known) => exe.contains(known) || bundle.contains(known) || name.contains(known),
    );
  }

  void _emit(bool isActive) {
    _isMeetingActive = isActive;
    _controller.add(isActive);
    IpcBridge.instance.notifyMeetingDetected(isActive);
  }
}
