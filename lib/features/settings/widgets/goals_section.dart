import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/presentation/widgets/category_budgets_card.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Personal targets and how you are doing against them.
///
/// Goals are measures, not rules: BreakMate shows progress here and on your
/// stats, it never blocks you or forces a break when a goal is met. Anything
/// about permissions or data collection lives in Privacy, and Calendar Sync has
/// its own screen.
class GoalsSection extends StatelessWidget {
  const GoalsSection({super.key});

  /// Distinct days in the last 7 (including today) with at least one
  /// completed break.
  static int activeDaysThisWeek(List<DailyStats> weekly, DateTime now) {
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final days = {
      for (var i = 0; i < 7; i++)
        key(DateTime(now.year, now.month, now.day - i)),
    };
    return weekly
        .where((d) => days.contains(d.date) && d.breaksCompleted > 0)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsRepository, StatsService>(
      builder: (context, repo, statsService, _) {
        final s = repo.currentSettings;
        final stats = statsService.stats;
        final activeDays = activeDaysThisWeek(stats.weeklyData, clock.now());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader(
              'Personal Goals',
              subtitle:
                  'Targets to aim for. BreakMate tracks your progress but '
                  'never blocks you or forces a break when you reach one.',
            ),
            const SizedBox(height: 4),
            buildCard([
              ValueListenableBuilder<Duration>(
                valueListenable: sl<TimerEngine>().totalWorkTodayNotifier,
                builder: (context, worked, _) => _GoalRow(
                  title: 'Daily focus time',
                  effect:
                      'Progress counts the time your work timer has run '
                      'today. Resets each morning.',
                  progressLabel:
                      '${_hm(worked)} of ${s.dailyWorkGoalHours}h today',
                  progress: worked.inMinutes / (s.dailyWorkGoalHours * 60),
                  value: s.dailyWorkGoalHours.toDouble(),
                  min: 1,
                  max: 12,
                  valueLabel: '${s.dailyWorkGoalHours}h',
                  onChanged: (v) =>
                      repo.save(s.copyWith(dailyWorkGoalHours: v.round())),
                ),
              ),
              divider(),
              _GoalRow(
                title: 'Daily breaks',
                effect:
                    'Counts breaks you complete (skipped ones don\'t '
                    'count). Resets each morning.',
                progressLabel:
                    '${stats.breaksCompleted} of ${s.dailyBreakGoalCount} today',
                progress: stats.breaksCompleted / s.dailyBreakGoalCount,
                value: s.dailyBreakGoalCount.toDouble(),
                min: 1,
                max: 30,
                valueLabel: '${s.dailyBreakGoalCount}',
                onChanged: (v) =>
                    repo.save(s.copyWith(dailyBreakGoalCount: v.round())),
              ),
              divider(),
              _GoalRow(
                title: 'Weekly consistency',
                effect:
                    'A day counts when you complete at least one break. '
                    'Looks at the last 7 days.',
                progressLabel:
                    '$activeDays of ${s.weeklyConsistencyTargetDays} days',
                progress: activeDays / s.weeklyConsistencyTargetDays,
                value: s.weeklyConsistencyTargetDays.toDouble(),
                min: 1,
                max: 7,
                valueLabel:
                    '${s.weeklyConsistencyTargetDays} day${s.weeklyConsistencyTargetDays == 1 ? '' : 's'}',
                onChanged: (v) => repo.save(
                  s.copyWith(weeklyConsistencyTargetDays: v.round()),
                ),
              ),
            ]),
            sectionHeader(
              'App time budgets',
              subtitle: s.appUsageTrackingEnabled
                  ? 'Daily limits per kind of app. You get a gentle nudge in '
                        'your insights when one is exceeded.'
                  : 'Needs app usage tracking, which is off. Turn it on in '
                        'Privacy to use budgets.',
            ),
            if (s.appUsageTrackingEnabled)
              CategoryBudgetsCard(
                budgetMinutes: s.categoryDailyBudgetMinutes,
                onChanged: (updated) =>
                    repo.save(s.copyWith(categoryDailyBudgetMinutes: updated)),
              ),
          ],
        );
      },
    );
  }

  static String _hm(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h == 0 ? '${m}m' : '${h}h ${m}m';
  }
}

class _GoalRow extends StatelessWidget {
  final String title;
  final String effect;
  final String progressLabel;
  final double progress;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _GoalRow({
    required this.title,
    required this.effect,
    required this.progressLabel,
    required this.progress,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final met = progress >= 1;
    final color = met ? AppTheme.success : AppTheme.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                met ? '$progressLabel ✓' : progressLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              color: color,
              backgroundColor: AppTheme.border,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            effect,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: AppTheme.textSecondary,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: (max - min).round(),
                  label: valueLabel,
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  valueLabel,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
