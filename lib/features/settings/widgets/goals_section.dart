import 'settings_group.dart';
import 'rest_day_settings.dart';
import 'package:breakmate/features/analytics/weekly_goal_progress.dart';
import 'package:breakmate/shared/utils/reduced_motion.dart';
import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/presentation/widgets/category_budgets_card.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/features/settings/widgets/settings_widgets.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Settings > Goals: daily focus/break targets with live progress from [TimerEngine] and [StatsService].
class GoalsSection extends StatelessWidget {
  const GoalsSection({super.key});

  /// Days in the last 7 (including today) with at least one completed break.
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
        final week = WeeklyGoalProgress.calculate(
          stats.weeklyData,
          clock.now(),
          s.weeklyConsistencyTargetDays,
          s.experience,
        );
        final activeDays = week.activeDays;

        return ValueListenableBuilder<Duration>(
          valueListenable: sl<TimerEngine>().totalWorkTodayNotifier,
          builder: (context, worked, _) {
            final focusP =
                worked.inMinutes / (s.dailyWorkGoalHours.clamp(1, 12) * 60);
            final breakP =
                stats.breaksCompleted / s.dailyBreakGoalCount.clamp(1, 30);
            final weekP = week.progress;
            final all = [
              if (!week.restingToday) ...[focusP, breakP],
              weekP,
            ];
            final metCount = all.where((p) => p >= 1).length;
            final overall =
                all.map((p) => p.clamp(0.0, 1.0)).reduce((a, b) => a + b) /
                all.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Summary(
                  overall: overall,
                  metCount: metCount,
                  totalGoals: all.length,
                ),
                SettingsNote(
                  week.restingToday
                      ? 'Today is a rest day. There is nothing to make up.'
                      : 'A missed day does not erase the breaks you have taken.',
                ),
                RestDaySettings(settings: s, onSave: repo.save),
                sectionHeader('Targets'),
                SettingsGroup(
                  children: [
                    if (!week.restingToday) ...[
                      _GoalRow(
                        title: 'Daily focus time',
                        effect: 'Time your work timer has run today',
                        current: _hm(worked),
                        target: '${s.dailyWorkGoalHours}h',
                        progress: focusP,
                        value: s.dailyWorkGoalHours.toDouble(),
                        min: 1,
                        max: 12,
                        onChanged: (v) => repo.save(
                          s.copyWith(dailyWorkGoalHours: v.round()),
                        ),
                      ),
                      _GoalRow(
                        title: 'Daily breaks',
                        effect:
                            'Completed breaks today; skipped ones do not count',
                        current: '${stats.breaksCompleted}',
                        target: '${s.dailyBreakGoalCount}',
                        progress: breakP,
                        value: s.dailyBreakGoalCount.toDouble(),
                        min: 1,
                        max: 30,
                        onChanged: (v) => repo.save(
                          s.copyWith(dailyBreakGoalCount: v.round()),
                        ),
                      ),
                    ],
                    _GoalRow(
                      title: 'Weekly consistency',
                      effect:
                          'Days in the last 7 with at least one completed break. Planned target: ${s.weeklyConsistencyTargetDays} days; rest days lower it',
                      current: '$activeDays',
                      target:
                          '${week.targetDays} day${week.targetDays == 1 ? '' : 's'}',
                      progress: weekP,
                      value: s.weeklyConsistencyTargetDays.toDouble(),
                      min: 1,
                      max: 7,
                      onChanged: (v) => repo.save(
                        s.copyWith(weeklyConsistencyTargetDays: v.round()),
                      ),
                    ),
                  ],
                ),
                sectionHeader(
                  'App time budgets',
                  subtitle: s.appUsageTrackingEnabled
                      ? 'Soft daily limits. Reaching one adds a note to your insights; nothing is blocked.'
                      : 'Needs app usage tracking, which is off. Turn it on in Privacy.',
                ),
                if (s.appUsageTrackingEnabled)
                  CategoryBudgetsCard(
                    budgetMinutes: s.categoryDailyBudgetMinutes,
                    onChanged: (updated) => repo.save(
                      s.copyWith(categoryDailyBudgetMinutes: updated),
                    ),
                  ),
              ],
            );
          },
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

class _Summary extends StatelessWidget {
  final double overall;
  final int metCount;
  final int totalGoals;

  const _Summary({
    required this.overall,
    required this.metCount,
    required this.totalGoals,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$metCount',
                style: TextStyle(
                  fontFeatures: AppTheme.tabular,
                  fontSize: 40,
                  height: 1,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'of $totalGoals goals reached',
                style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: overall.clamp(0.0, 1.0)),
            duration: motionDuration(
              context,
              const Duration(milliseconds: 600),
            ),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => _Hairline(value: v, height: 3),
          ),
          const SizedBox(height: 16),
          Text(
            'Targets to aim for. Nothing is blocked or forced when you reach one.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  final double value;
  final double height;
  final bool met;

  const _Hairline({required this.value, this.height = 2, this.met = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          Container(height: height, color: AppTheme.border),
          Container(
            height: height,
            width: c.maxWidth * value.clamp(0.0, 1.0),
            color: met ? AppTheme.success : AppTheme.textPrimary,
          ),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final String title;
  final String effect;
  final String current;
  final String target;
  final double progress;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _GoalRow({
    required this.title,
    required this.effect,
    required this.current,
    required this.target,
    required this.progress,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final met = progress >= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (met)
                    Text(
                      'Reached',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    current,
                    style: TextStyle(
                      fontFeatures: AppTheme.tabular,
                      fontSize: 24,
                      height: 1,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'of $target',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: motionDuration(
                  context,
                  const Duration(milliseconds: 500),
                ),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => _Hairline(value: v, met: met),
              ),
              const SizedBox(height: 12),
              Text(
                effect,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Target',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const Spacer(),
                  _StepButton(
                    icon: CupertinoIcons.minus,
                    tooltip: 'Decrease target',
                    onTap: value > min ? () => onChanged(value - 1) : null,
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      target,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFeatures: AppTheme.tabular,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: CupertinoIcons.add,
                    tooltip: 'Increase target',
                    onTap: value < max ? () => onChanged(value + 1) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(
            icon,
            size: 14,
            color: onTap == null ? AppTheme.textMuted : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
