import 'package:flutter/foundation.dart';

/// Counts app switches in a sliding window to flag fragmented work.
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

  bool isHighSwitchRate(DateTime now, {int threshold = 12}) {
    return switchesInWindow(now) >= threshold;
  }

  void _prune(DateTime now) {
    final cutoff = now.subtract(window);
    _switches.removeWhere((t) => t.isBefore(cutoff));
  }
}
