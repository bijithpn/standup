// Coverage for the Overview tab's unified Insights card — surfacing the top
// findings from data the Focus/App Usage tabs already compute individually
// (BreakFocusCorrelation, category budgets, focus streak) plus the
// break-skip check the roadmap asked for.
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/analytics/break_focus_correlation.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/calendar_focus_insight.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/insights_overview.dart';
import 'package:breakmate/features/analytics/meeting_break_insight.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';

BreakEvent _event(int hour, bool completed) =>
    BreakEvent(time: DateTime(2026, 1, 1, hour), completed: completed);

FocusSession _session(int hour, int durationSeconds) => FocusSession(
  start: DateTime(2026, 1, 1, hour),
  durationSeconds: durationSeconds,
  category: AppCategory.coding,
);

void main() {
  group('buildOverviewInsights', () {
    test('empty input produces no findings', () {
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
      );
      expect(insights, isEmpty);
    });

    test('flags a high break-skip rate this week', () {
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 2,
        breaksSkippedThisWeek: 4,
      );
      expect(insights, isNotEmpty);
      expect(insights.first.text, contains('skipped 4 of 6'));
    });

    test('does not flag a low break-skip rate', () {
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 9,
        breaksSkippedThisWeek: 1,
      );
      expect(insights.where((i) => i.text.contains('skipped')), isEmpty);
    });

    test('does not flag skips below the 3-break sample floor', () {
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 1,
      );
      expect(insights, isEmpty);
    });

    test('flags a category over its daily budget', () {
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {AppCategory.browsing: 3600},
        budgetMinutes: const {'browsing': 30},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
      );
      expect(insights.single.text, contains('Browsing'));
    });

    test('surfaces the break-focus correlation once there is enough data '
        'and the gap is meaningful', () {
      const correlation = BreakFocusCorrelation(
        afterCompletedScore: 0.8,
        afterSkippedScore: 0.5,
        completedSampleCount: 5,
        skippedSampleCount: 5,
      );
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        correlation: correlation,
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
      );
      expect(insights.single.text, correlation.describe());
    });

    test('ignores a correlation with an insignificant gap', () {
      const correlation = BreakFocusCorrelation(
        afterCompletedScore: 0.51,
        afterSkippedScore: 0.50,
        completedSampleCount: 5,
        skippedSampleCount: 5,
      );
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        correlation: correlation,
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
      );
      expect(insights, isEmpty);
    });

    test('ignores a correlation without enough samples on both sides', () {
      const correlation = BreakFocusCorrelation(
        afterCompletedScore: 0.9,
        afterSkippedScore: 0.1,
        completedSampleCount: 3,
        skippedSampleCount: 0,
      );
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        correlation: correlation,
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
      );
      expect(insights, isEmpty);
    });

    test('flags a focus streak of 2+ days', () {
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 3,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
      );
      expect(insights.single.text, contains('3-day focus streak'));
    });

    test('does not flag a 1-day streak', () {
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 1,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
      );
      expect(insights, isEmpty);
    });

    test('attaches a shorten-interval action to the skip-rate finding '
        'when a current interval is given', () {
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 2,
        breaksSkippedThisWeek: 4,
        currentLongBreakIntervalMinutes: 60,
      );
      final action = insights.first.action;
      expect(action, isNotNull);
      expect(action!.label, contains('45m'));

      const settings = SettingsModel(longBreakIntervalMinutes: 60);
      final applied = action.apply(settings);
      expect(applied.longBreakIntervalMinutes, 45);
    });

    test('does not attach an action when no current interval is given', () {
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 2,
        breaksSkippedThisWeek: 4,
      );
      expect(insights.first.action, isNull);
    });

    test('the shorten-interval action never goes below the floor', () {
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 2,
        breaksSkippedThisWeek: 4,
        currentLongBreakIntervalMinutes: 25,
      );
      const settings = SettingsModel(longBreakIntervalMinutes: 25);
      final applied = insights.first.action!.apply(settings);
      expect(applied.longBreakIntervalMinutes, 20);
    });

    test('does not attach an action when already at the floor', () {
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 2,
        breaksSkippedThisWeek: 4,
        currentLongBreakIntervalMinutes: 20,
      );
      expect(insights.first.action, isNull);
    });

    test('flags a bad break hour once there is enough data and the skip '
        'rate is high', () {
      final events = [
        _event(14, false),
        _event(14, false),
        _event(14, false),
      ];
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
        breakEvents: events,
      );
      expect(insights.single.text, contains('2pm'));
    });

    test('does not flag a break hour below the skip-rate threshold', () {
      final events = [_event(14, false), _event(14, true), _event(14, true)];
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
        breakEvents: events,
      );
      expect(insights, isEmpty);
    });

    test('surfaces a golden focus hour once there is enough data', () {
      final sessions = [
        _session(9, 1800),
        _session(9, 1800),
        _session(14, 300),
      ];
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
        focusSessions: sessions,
      );
      expect(insights.single.text, contains('9am'));
    });

    test('surfaces a meaningful calendar-focus drop', () {
      const comparison = CalendarFocusComparison(
        heavyDayAverageFocusScore: 0.3,
        lightDayAverageFocusScore: 0.7,
        heavyDayCount: 3,
        lightDayCount: 3,
      );
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
        calendarComparison: comparison,
      );
      expect(insights.single.text, comparison.describe());
    });

    test('ignores a calendar comparison without enough data', () {
      const comparison = CalendarFocusComparison(
        heavyDayAverageFocusScore: 0.3,
        lightDayAverageFocusScore: 0.7,
        heavyDayCount: 1,
        lightDayCount: 1,
      );
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
        calendarComparison: comparison,
      );
      expect(insights, isEmpty);
    });

    test('surfaces a meaningful break-before-meeting skip pattern', () {
      const correlation = MeetingBreakCorrelation(
        nearMeetingCount: 5,
        nearMeetingSkipped: 4,
        otherCount: 5,
        otherSkipped: 1,
      );
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
        meetingBreakCorrelation: correlation,
      );
      expect(insights.single.text, correlation.describe());
    });

    test('ignores a meeting-break correlation without enough data', () {
      const correlation = MeetingBreakCorrelation(
        nearMeetingCount: 1,
        nearMeetingSkipped: 1,
        otherCount: 5,
        otherSkipped: 1,
      );
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {},
        budgetMinutes: const {},
        focusStreakDays: 0,
        breaksCompletedThisWeek: 0,
        breaksSkippedThisWeek: 0,
        meetingBreakCorrelation: correlation,
      );
      expect(insights, isEmpty);
    });

    test('respects the limit, ranked in a stable order', () {
      const correlation = BreakFocusCorrelation(
        afterCompletedScore: 0.8,
        afterSkippedScore: 0.5,
        completedSampleCount: 5,
        skippedSampleCount: 5,
      );
      final insights = buildOverviewInsights(
        todayCategoryTotals: const {AppCategory.browsing: 3600},
        budgetMinutes: const {'browsing': 30},
        correlation: correlation,
        focusStreakDays: 5,
        breaksCompletedThisWeek: 2,
        breaksSkippedThisWeek: 4,
        limit: 2,
      );
      expect(insights, hasLength(2));
      expect(insights[0].text, contains('skipped'));
      expect(insights[1].text, contains('budget'));
    });
  });
}
