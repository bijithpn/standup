import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/display/services/display_manager.dart';
import 'package:breakmate/app/dependency_injection.dart';

/// Watches for another app's window covering (most of) the primary display —
/// the shape of a fullscreen slideshow, Keynote/PowerPoint presentation, or a
/// fullscreen video call — and exposes it as [isPresenting].
///
/// This is a heuristic proxy for "the user is presenting or screen-sharing".
/// It is pure Dart, built entirely on [NativeBridge.getVisibleWindows] and
/// [DisplayManager.getPrimaryDisplay] — both already implemented natively on
/// macOS and Windows — so presentation-pause works identically on both
/// platforms without any bespoke native polling code.
class PresentationDetectionService {
  static const double _coverageThreshold = 0.95;
  static const Duration _pollInterval = Duration(seconds: 2);

  final DisplayManager _displayManager;

  PresentationDetectionService({DisplayManager? displayManager})
    : _displayManager = displayManager ?? sl<DisplayManager>();

  Timer? _timer;
  bool _isRunning = false;
  bool _isPresenting = false;

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

      _isPresenting = windows.any((w) {
        if (!w.isVisible || w.isMinimized) return false;
        final windowArea = w.width * w.height;
        return windowArea >= screenArea * _coverageThreshold;
      });
    } catch (e) {
      debugPrint('PresentationDetectionService poll error: $e');
    }
  }
}
