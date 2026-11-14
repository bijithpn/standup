import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/analytics/app_usage_insights.dart';
import 'package:breakmate/features/analytics/break_focus_correlation.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/calendar_focus_insight.dart';
import 'package:breakmate/features/analytics/focus_session_models.dart';
import 'package:breakmate/features/analytics/meeting_break_insight.dart';
import 'package:breakmate/features/analytics/time_pattern_insights.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// One-tap settings change attached to an insight.
class InsightAction {
  final String label;
  final SettingsModel Function(SettingsModel current) apply;

  const InsightAction({required this.label, required this.apply});
}

class OverviewInsight {
  final IconData icon;
  final Color color;
  final String text;
  final InsightAction? action;

  const OverviewInsight({
    required this.icon,
    required this.color,
    required this.text,
    this.action,
  });
}

const int _minSuggestedIntervalMinutes = 20;

const int _intervalShortenStepMinutes = 15;

const double _meaningfulMeetingSkipDeltaPoints = 15;

/// Builds prioritized, data-gated insights (skips, budgets, correlations, hours, meetings); order is priority and result is capped at [limit].
List<OverviewInsight> buildOverviewInsights({
  required Map<AppCategory, int> todayCategoryTotals,
  required Map<String, int> budgetMinutes,
  BreakFocusCorrelation? correlation,
  required int focusStreakDays,
  required int breaksCompletedThisWeek,
  required int breaksSkippedThisWeek,
  int? currentLongBreakIntervalMinutes,
  List<BreakEvent> breakEvents = const [],
  List<FocusSession> focusSessions = const [],
  CalendarFocusComparison? calendarComparison,
  MeetingBreakCorrelation? meetingBreakCorrelation,
  int limit = 4,
}) {
  final insights = <OverviewInsight>[];

  final totalBreaksThisWeek = breaksCompletedThisWeek + breaksSkippedThisWeek;
  if (totalBreaksThisWeek >= 3 &&
      breaksSkippedThisWeek / totalBreaksThisWeek >= 0.4) {
    final currentInterval = currentLongBreakIntervalMinutes;
    final canShorten =
        currentInterval != null &&
        currentInterval > _minSuggestedIntervalMinutes;
    final newInterval = canShorten
        ? (currentInterval - _intervalShortenStepMinutes).clamp(
            _minSuggestedIntervalMinutes,
            currentInterval,
          )
        : null;

    insights.add(
      OverviewInsight(
        icon: CupertinoIcons.exclamationmark_circle,
        color: AppTheme.warning,
        text:
            "You've skipped $breaksSkippedThisWeek of $totalBreaksThisWeek "
            "breaks this week — worth trying a shorter break or a different time of day?",
        action: newInterval == null
            ? null
            : InsightAction(
                label: 'Shorten break interval to ${newInterval}m',
                apply: (settings) =>
                    settings.copyWith(longBreakIntervalMinutes: newInterval),
              ),
      ),
    );
  }

  final overBudget = categoriesOverBudget(
    todayCategorySeconds: todayCategoryTotals,
    budgetMinutes: budgetMinutes,
  );
  if (overBudget.isNotEmpty) {
    final names = overBudget.map((c) => c.label).join(', ');
    insights.add(
      OverviewInsight(
        icon: CupertinoIcons.timer,
        color: AppTheme.warning,
        text: "Today's budget is used up for $names.",
      ),
    );
  }

  if (correlation != null &&
      correlation.hasEnoughData &&
      correlation.differencePoints.abs() >= 5) {
    insights.add(
      OverviewInsight(
        icon: CupertinoIcons.link,
        color: AppTheme.accentColor,
        text: correlation.describe(),
      ),
    );
  }

  if (focusStreakDays >= 2) {
    insights.add(
      OverviewInsight(
        icon: CupertinoIcons.bolt_fill,
        color: AppTheme.accent,
        text: '$focusStreakDays-day focus streak going — keep it up.',
      ),
    );
  }

  final worstHour = worstBreakHour(breakEvents);
  if (worstHour != null) {
    final rate = breakSkipRateAtHour(breakEvents, worstHour);
    if (rate >= 0.4) {
      insights.add(
        OverviewInsight(
          icon: CupertinoIcons.clock,
          color: AppTheme.warning,
          text:
              'Breaks around ${formatHourLabel(worstHour)} get skipped '
              '${(rate * 100).round()}% of the time — your other break '
              'times work better for you.',
          action: InsightAction(
            label: 'Move breaks out of ${formatHourLabel(worstHour)}',
            apply: (s) => s.copyWith(avoidBreakHour: worstHour),
          ),
        ),
      );
    }
  }

  final goldenHour = goldenFocusHour(focusSessions);
  if (goldenHour != null) {
    insights.add(
      OverviewInsight(
        icon: CupertinoIcons.sun_max,
        color: AppTheme.accent,
        text:
            'Your deepest focus tends to land around '
            '${formatHourLabel(goldenHour)}.',
      ),
    );
  }

  if (calendarComparison != null &&
      calendarComparison.hasEnoughData &&
      calendarComparison.dropPercentPoints >= meaningfulFocusDropPoints) {
    insights.add(
      OverviewInsight(
        icon: CupertinoIcons.calendar,
        color: AppTheme.warning,
        text: calendarComparison.describe(),
      ),
    );
  }

  if (meetingBreakCorrelation != null &&
      meetingBreakCorrelation.hasEnoughData &&
      meetingBreakCorrelation.skipRateDeltaPoints >=
          _meaningfulMeetingSkipDeltaPoints) {
    insights.add(
      OverviewInsight(
        icon: CupertinoIcons.calendar_badge_plus,
        color: AppTheme.warning,
        text: meetingBreakCorrelation.describe(),
      ),
    );
  }

  return insights.take(limit).toList();
}
