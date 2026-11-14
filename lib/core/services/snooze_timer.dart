import 'dart:async';
import 'package:clock/clock.dart';

/// Owns a single pause deadline so replacing a snooze cancels its old callback.
class SnoozeTimer {
  Timer? _timer;
  DateTime? resumeAt;

  void start(Duration duration, void Function() onResume) {
    cancel();
    resumeAt = clock.now().add(duration);
    _timer = Timer(duration, () {
      _timer = null;
      resumeAt = null;
      onResume();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    resumeAt = null;
  }
}
