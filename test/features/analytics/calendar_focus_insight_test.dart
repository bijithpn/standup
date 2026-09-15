// Coverage for the calendar-aware insight (plan doc §7.4) — a comparison
// Opsis can't make (no calendar access) but BreakMate already can.
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/calendar_focus_insight.dart';

void main() {
  group('CalendarFocusComparison.compute', () {
    test('splits days into heavy vs light by the meeting threshold', () {
      final comparison = CalendarFocusComparison.compute(
        meetingCountByDate: {
          'd1': 5, 'd2': 6, 'd3': 4, // heavy (>= 4)
          'd4': 0, 'd5': 1, 'd6': 2, // light
        },
        focusScoreByDate: {
          'd1': 0.2, 'd2': 0.3, 'd3': 0.4, // avg 0.3
          'd4': 0.8, 'd5': 0.7, 'd6': 0.6, // avg 0.7
        },
      );

      expect(comparison.heavyDayCount, 3);
      expect(comparison.lightDayCount, 3);
      expect(comparison.heavyDayAverageFocusScore, closeTo(0.3, 0.001));
      expect(comparison.lightDayAverageFocusScore, closeTo(0.7, 0.001));
      expect(comparison.dropPercentPoints, closeTo(40, 0.01));
      expect(comparison.hasEnoughData, isTrue);
    });

    test('ignores a meeting-count date with no matching focus score', () {
      final comparison = CalendarFocusComparison.compute(
        meetingCountByDate: {'d1': 5, 'd2': 0},
        focusScoreByDate: {'d2': 0.5},
      );
      expect(comparison.heavyDayCount, 0);
      expect(comparison.lightDayCount, 1);
    });

    test('hasEnoughData is false below the sample floor on either side', () {
      final comparison = CalendarFocusComparison.compute(
        meetingCountByDate: {'d1': 5, 'd2': 0, 'd3': 0, 'd4': 0},
        focusScoreByDate: {'d1': 0.2, 'd2': 0.5, 'd3': 0.5, 'd4': 0.5},
      );
      expect(comparison.heavyDayCount, 1);
      expect(comparison.hasEnoughData, isFalse);
    });
  });

  group('describe', () {
    test('describes a drop on heavy-meeting days', () {
      const comparison = CalendarFocusComparison(
        heavyDayAverageFocusScore: 0.3,
        lightDayAverageFocusScore: 0.7,
        heavyDayCount: 3,
        lightDayCount: 3,
      );
      expect(comparison.describe(), contains('drops 40 points'));
    });

    test('describes a rise on heavy-meeting days', () {
      const comparison = CalendarFocusComparison(
        heavyDayAverageFocusScore: 0.7,
        lightDayAverageFocusScore: 0.3,
        heavyDayCount: 3,
        lightDayCount: 3,
      );
      expect(comparison.describe(), contains('rises 40 points'));
    });

    test('describes an insignificant gap as "about the same"', () {
      const comparison = CalendarFocusComparison(
        heavyDayAverageFocusScore: 0.5,
        lightDayAverageFocusScore: 0.505,
        heavyDayCount: 3,
        lightDayCount: 3,
      );
      expect(comparison.describe(), contains('about the same'));
    });
  });
}
