import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/display/services/display_manager.dart';
import 'package:breakmate/app/dependency_injection.dart';

/// Exposes [isPresenting]: a known presentation / screen-share app has a
/// window covering the primary display, seen on two consecutive polls.
/// Window coverage alone also matches any fullscreen app or Space switch, so
/// the owner app / title must match [_presentationHints] too.
class PresentationDetectionService {
  static const double _coverageThreshold = 0.95;
  static final _presentationHints = RegExp(
    r'keynote|powerpoint|slide ?show|presenter|google slides|libreoffice impress|'
    r'zoom\.us|zoom meeting|microsoft teams|webex|screen shar',
    caseSensitive: false,
  );
  // The result only decides how the next break is presented, so a few seconds
  // of staleness is invisible while each poll enumerates every window.
  static const Duration _pollInterval = Duration(seconds: 5);

  final DisplayManager _displayManager;

  PresentationDetectionService({DisplayManager? displayManager})
    : _displayManager = displayManager ?? sl<DisplayManager>();

  Timer? _timer;
  bool _isRunning = false;
  bool _isPresenting = false;
  bool _seenLastPoll = false;

  bool get isPresenting => _isPresenting;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
    unawaited(_poll());
    debugPrint('PresentationDetectionService started');
  }

  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _isPresenting = false;
    _seenLastPoll = false;
    debugPrint('PresentationDetectionService stopped');
  }

  Future<void> _poll() async {
    try {
      final screen = _displayManager.getPrimaryDisplay();
      if (screen == null) {
        _isPresenting = false;
        return;
      }

      final windows = await NativeBridge.getVisibleWindows();
      final screenArea = screen.width * screen.height;
      if (screenArea <= 0) {
        _isPresenting = false;
        return;
      }

      final seen = windows.any((w) {
        if (!w.isVisible || w.isMinimized) return false;
        final windowArea = w.width * w.height;
        return windowArea >= screenArea * _coverageThreshold &&
            _presentationHints.hasMatch('${w.appBundleId} ${w.windowTitle}');
      });
      _isPresenting = seen && _seenLastPoll;
      _seenLastPoll = seen;
    } catch (e) {
      debugPrint('PresentationDetectionService poll error: $e');
    }
  }
}
