import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/context_switch_tracker.dart';

void main() {
  test('counts switches within the rolling window', () {
    final tracker = ContextSwitchTracker(window: const Duration(hours: 1));
    final now = DateTime(2026, 1, 1, 9, 0);

    tracker.recordSwitch(now);
    tracker.recordSwitch(now.add(const Duration(minutes: 10)));
    tracker.recordSwitch(now.add(const Duration(minutes: 20)));

    expect(
      tracker.switchesInWindow(now.add(const Duration(minutes: 30))),
      3,
    );
  });

  test('prunes switches older than the window', () {
    final tracker = ContextSwitchTracker(window: const Duration(hours: 1));
    final now = DateTime(2026, 1, 1, 9, 0);

    tracker.recordSwitch(now);
    tracker.recordSwitch(now.add(const Duration(minutes: 90)));

    // The first switch is now 90 minutes in the past, outside the 1-hour window.
    expect(
      tracker.switchesInWindow(now.add(const Duration(minutes: 90))),
      1,
    );
  });

  test('isHighSwitchRate reflects the configured threshold', () {
    final tracker = ContextSwitchTracker();
    final now = DateTime(2026, 1, 1, 9, 0);

    for (var i = 0; i < 11; i++) {
      tracker.recordSwitch(now.add(Duration(minutes: i)));
    }
    expect(tracker.isHighSwitchRate(now, threshold: 12), isFalse);

    tracker.recordSwitch(now.add(const Duration(minutes: 11)));
    expect(tracker.isHighSwitchRate(now, threshold: 12), isTrue);
  });

  test('notifies listeners when a switch is recorded', () {
    final tracker = ContextSwitchTracker();
    var notified = false;
    tracker.addListener(() => notified = true);

    tracker.recordSwitch(DateTime(2026, 1, 1, 9, 0));

    expect(notified, isTrue);
  });
}
