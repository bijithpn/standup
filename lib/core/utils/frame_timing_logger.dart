import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

const bool kEnableFrameTimingLog = false;

class FrameTimingLogger {
  FrameTimingLogger._();
  static final FrameTimingLogger instance = FrameTimingLogger._();

  String _currentState = 'unknown';
  bool _running = false;

  void setAppState(String state) {
    _currentState = state;
  }

  void start() {
    if (!kDebugMode || !kEnableFrameTimingLog || _running) return;
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    debugPrint('[FrameTiming] Logger started');
  }

  void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    debugPrint('[FrameTiming] Logger stopped');
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final buildMs = t.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000.0;
      final totalMs = buildMs + rasterMs;

      if (totalMs >= 100) {
        debugPrint(
          '[FrameTiming] 🔴 JANK >100ms  build=${buildMs.toStringAsFixed(1)}ms '
          'raster=${rasterMs.toStringAsFixed(1)}ms  state=$_currentState',
        );
      } else if (totalMs >= 33) {
        debugPrint(
          '[FrameTiming] 🟠 SLOW >33ms   build=${buildMs.toStringAsFixed(1)}ms '
          'raster=${rasterMs.toStringAsFixed(1)}ms  state=$_currentState',
        );
      } else if (totalMs >= 16) {
        debugPrint(
          '[FrameTiming] 🟡 SLOW >16ms   build=${buildMs.toStringAsFixed(1)}ms '
          'raster=${rasterMs.toStringAsFixed(1)}ms  state=$_currentState',
        );
      }
    }
  }
}
