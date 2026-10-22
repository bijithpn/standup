// Coverage for the break-before-meeting skip correlation (plan doc §7.6) —
// the third time-pattern finding sketched for §7.2/Phase 4.
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/meeting_break_insight.dart';

BreakEvent _event(DateTime time, bool completed) =>
    BreakEvent(time: time, completed: completed);

void main() {
  group('MeetingBreakCorrelation.compute', () {
    test(
      'buckets a break as near-meeting when a meeting starts soon after',
      () {
        final breakTime = DateTime(2026, 1, 1, 10, 0);
        final correlation = MeetingBreakCorrelation.compute(
          breakEvents: [_event(breakTime, false)],
          meetingStartTimes: [breakTime.add(const Duration(minutes: 10))],
        );
        expect(correlation.nearMeetingCount, 1);
        expect(correlation.otherCount, 0);
      },
    );

    test('does not bucket a break as near-meeting outside the window', () {
      final breakTime = DateTime(2026, 1, 1, 10, 0);
      final correlation = MeetingBreakCorrelation.compute(
        breakEvents: [_event(breakTime, false)],
        meetingStartTimes: [breakTime.add(const Duration(minutes: 30))],
      );
      expect(correlation.nearMeetingCount, 0);
      expect(correlation.otherCount, 1);
    });

    test('ignores a meeting that starts before the break', () {
      final breakTime = DateTime(2026, 1, 1, 10, 0);
      final correlation = MeetingBreakCorrelation.compute(
        breakEvents: [_event(breakTime, false)],
        meetingStartTimes: [breakTime.subtract(const Duration(minutes: 5))],
      );
      expect(correlation.nearMeetingCount, 0);
      expect(correlation.otherCount, 1);
    });

    test('computes skip rates for each bucket', () {
      final meetingStart = DateTime(2026, 1, 1, 12, 0);
      final events = [
        _event(DateTime(2026, 1, 1, 11, 55), false), // near, skipped
        _event(DateTime(2026, 1, 1, 11, 50), true), // near, completed
        _event(DateTime(2026, 1, 1, 9, 0), true), // other, completed
        _event(DateTime(2026, 1, 1, 8, 0), true), // other, completed
      ];
      final correlation = MeetingBreakCorrelation.compute(
        breakEvents: events,
        meetingStartTimes: [meetingStart],
      );
      expect(correlation.nearMeetingCount, 2);
      expect(correlation.nearMeetingSkipRate, closeTo(0.5, 0.001));
      expect(correlation.otherCount, 2);
      expect(correlation.otherSkipRate, closeTo(0.0, 0.001));
      expect(correlation.skipRateDeltaPoints, closeTo(50, 0.01));
    });

    test('hasEnoughData is false below the sample floor on either side', () {
      final correlation = MeetingBreakCorrelation.compute(
        breakEvents: [
          _event(DateTime(2026, 1, 1, 10), false),
          _event(DateTime(2026, 1, 1, 9), true),
        ],
        meetingStartTimes: [DateTime(2026, 1, 1, 10, 10)],
      );
      expect(correlation.hasEnoughData, isFalse);
    });
  });

  group('describe', () {
    test('describes breaks skipped more often before a meeting', () {
      const correlation = MeetingBreakCorrelation(
        nearMeetingCount: 5,
        nearMeetingSkipped: 4,
        otherCount: 5,
        otherSkipped: 1,
      );
      expect(correlation.describe(), contains('60% more often'));
    });

    test('describes breaks skipped less often before a meeting', () {
      const correlation = MeetingBreakCorrelation(
        nearMeetingCount: 5,
        nearMeetingSkipped: 1,
        otherCount: 5,
        otherSkipped: 4,
      );
      expect(correlation.describe(), contains('60% less often'));
    });
  });
}
