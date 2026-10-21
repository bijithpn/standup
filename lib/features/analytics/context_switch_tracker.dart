import 'package:flutter/foundation.dart';

/// Tracks how often the active app changes, as a cheap proxy for fragmented
/// attention. Deliberately in-memory only — a live "right now" signal, not
/// a historical stat worth persisting across restarts — fed by
/// [AppUsageTracker] every time the polled app differs from the previous
/// tick, and queried by [TimerContextManager] to inform (never silently
/// act on) break timing.
class ContextSwitchTracker extends ChangeNotifier {
  final Duration window;
  final List<DateTime> _switches = [];

  ContextSwitchTracker({this.window = const Duration(hours: 1)});

  void recordSwitch(DateTime now) {
    _switches.add(now);
    _prune(now);
    notifyListeners();
  }

  int switchesInWindow(DateTime now) {
    _prune(now);
    return _switches.length;
  }

  /// True once switching is frequent enough to suggest fragmented focus.
  /// The default — 12/hour, roughly one switch every 5 minutes — is a soft
  /// heuristic meant to power a nudge or a dashboard note, not a threshold
  /// that should ever silently change break timing on its own.
  bool isHighSwitchRate(DateTime now, {int threshold = 12}) {
    return switchesInWindow(now) >= threshold;
  }

  void _prune(DateTime now) {
    final cutoff = now.subtract(window);
    _switches.removeWhere((t) => t.isBefore(cutoff));
  }
}
