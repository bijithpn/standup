// Coverage for the time-of-day findings (plan doc Phase 4 / §7.2): the
// richest unused signal in break/focus history — *when* things happen, not
// just how much.
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/time_pattern_insights.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

BreakEvent _event(int hour, bool completed) =>
    BreakEvent(time: DateTime(2026, 1, 1, hour), completed: completed);

FocusSession _session(int hour, int durationSeconds) => FocusSession(
  start: DateTime(2026, 1, 1, hour),
  durationSeconds: durationSeconds,
  category: AppCategory.coding,
);

void main() {
  group('worstBreakHour', () {
    test('returns null with no events', () {
      expect(worstBreakHour([]), isNull);
    });

    test('returns null when every hour is under the sample floor', () {
      final events = [_event(14, false), _event(9, true)];
      expect(worstBreakHour(events), isNull);
    });

    test('finds the hour with the highest skip rate once sampled enough', () {
      final events = [
        // 2pm: 3 skipped of 3 — 100%
        _event(14, false),
        _event(14, false),
        _event(14, false),
        // 9am: 1 skipped of 3 — 33%
        _event(9, false),
        _event(9, true),
        _event(9, true),
      ];
      expect(worstBreakHour(events), 14);
    });

    test('ties break toward the earliest hour', () {
      final events = [
        _event(14, false),
        _event(14, false),
        _event(14, true),
        _event(9, false),
        _event(9, false),
        _event(9, true),
      ];
      expect(worstBreakHour(events), 9);
    });
  });

  group('breakSkipRateAtHour', () {
    test('computes the rate for a given hour', () {
      final events = [_event(14, false), _event(14, true), _event(9, true)];
      expect(breakSkipRateAtHour(events, 14), 0.5);
    });

    test('returns 0.0 for an hour with no events', () {
      expect(breakSkipRateAtHour([], 14), 0.0);
    });
  });

  group('goldenFocusHour', () {
    test('returns null with fewer than the sample floor', () {
      expect(goldenFocusHour([_session(9, 100), _session(9, 100)]), isNull);
    });

    test('finds the hour with the most total focus time', () {
      final sessions = [_session(9, 900), _session(9, 900), _session(14, 300)];
      expect(goldenFocusHour(sessions), 9);
    });

    test('ties break toward the earliest hour', () {
      final sessions = [_session(14, 600), _session(9, 600), _session(9, 0)];
      expect(goldenFocusHour(sessions), 9);
    });
  });

  group('formatHourLabel', () {
    test('formats standard hours', () {
      expect(formatHourLabel(14), '2pm');
      expect(formatHourLabel(9), '9am');
    });

    test('formats midnight and noon', () {
      expect(formatHourLabel(0), '12am');
      expect(formatHourLabel(12), '12pm');
    });
  });
}
