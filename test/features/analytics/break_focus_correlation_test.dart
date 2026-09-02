import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/break_focus_correlation.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

void main() {
  test('reports no data when there are no break events', () {
    final result = BreakFocusCorrelation.compute(events: [], allSessions: []);

    expect(result.hasEnoughData, isFalse);
    expect(result.completedSampleCount, 0);
    expect(result.skippedSampleCount, 0);
  });

  test('needs at least one sample of each kind to be meaningful', () {
    final breakTime = DateTime(2026, 8, 31, 9, 0);
    final result = BreakFocusCorrelation.compute(
      events: [BreakEvent(time: breakTime, completed: true)],
      allSessions: [],
    );

    expect(result.hasEnoughData, isFalse);
  });

  test('scores full focus coverage in the hour after a completed break', () {
    final breakTime = DateTime(2026, 8, 31, 9, 0);
    final result = BreakFocusCorrelation.compute(
      events: [
        BreakEvent(time: breakTime, completed: true),
        BreakEvent(
          time: breakTime.add(const Duration(hours: 3)),
          completed: false,
        ),
      ],
      allSessions: [
        FocusSession(
          category: AppCategory.coding,
          start: breakTime,
          durationSeconds: 3600,
        ),
      ],
      window: const Duration(hours: 1),
    );

    expect(result.hasEnoughData, isTrue);
    expect(result.afterCompletedScore, closeTo(1.0, 0.001));
    expect(result.afterSkippedScore, closeTo(0.0, 0.001));
    expect(result.differencePoints, closeTo(100.0, 0.1));
  });

  test('only counts the overlap that falls inside the window', () {
    final breakTime = DateTime(2026, 8, 31, 9, 0);
    final result = BreakFocusCorrelation.compute(
      events: [
        BreakEvent(time: breakTime, completed: true),
        BreakEvent(
          time: breakTime.add(const Duration(hours: 3)),
          completed: false,
        ),
      ],
      allSessions: [
        // Starts 30 min before the window and runs 30 min into it.
        FocusSession(
          category: AppCategory.coding,
          start: breakTime.subtract(const Duration(minutes: 30)),
          durationSeconds: 3600,
        ),
      ],
      window: const Duration(hours: 1),
    );

    expect(result.afterCompletedScore, closeTo(0.5, 0.001));
  });

  test('averages across multiple events of the same kind', () {
    final breakTime = DateTime(2026, 8, 31, 9, 0);
    final result = BreakFocusCorrelation.compute(
      events: [
        BreakEvent(time: breakTime, completed: true),
        BreakEvent(
          time: breakTime.add(const Duration(hours: 5)),
          completed: true,
        ),
        BreakEvent(
          time: breakTime.add(const Duration(hours: 10)),
          completed: false,
        ),
      ],
      allSessions: [
        FocusSession(
          category: AppCategory.coding,
          start: breakTime,
          durationSeconds: 3600,
        ),
        // No session after the second completed break -> 0.0 for that one.
      ],
      window: const Duration(hours: 1),
    );

    expect(result.afterCompletedScore, closeTo(0.5, 0.001));
  });
}
