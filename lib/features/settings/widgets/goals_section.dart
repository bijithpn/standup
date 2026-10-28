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

        return ValueListenableBuilder<Duration>(
          valueListenable: sl<TimerEngine>().totalWorkTodayNotifier,
          builder: (context, worked, _) {
            final focusP = worked.inMinutes / (s.dailyWorkGoalHours * 60);
            final breakP = stats.breaksCompleted / s.dailyBreakGoalCount;
            final weekP = activeDays / s.weeklyConsistencyTargetDays;
            final all = [focusP, breakP, weekP];
            final metCount = all.where((p) => p >= 1).length;
            final overall =
                all.map((p) => p.clamp(0.0, 1.0)).reduce((a, b) => a + b) / 3;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Summary(overall: overall, metCount: metCount),
                _GoalRow(
                  index: 1,
                  title: 'Daily focus time',
                  effect:
                      'Counts the time your work timer has run today. '
                      'Resets each morning.',
                  current: _hm(worked),
                  target: '${s.dailyWorkGoalHours}h',
                  progress: focusP,
                  value: s.dailyWorkGoalHours.toDouble(),
                  min: 1,
                  max: 12,
                  onChanged: (v) =>
                      repo.save(s.copyWith(dailyWorkGoalHours: v.round())),
                ),
                _GoalRow(
                  index: 2,
                  title: 'Daily breaks',
                  effect:
                      'Counts breaks you complete (skipped ones don\'t). '
                      'Resets each morning.',
                  current: '${stats.breaksCompleted}',
                  target: '${s.dailyBreakGoalCount}',
                  progress: breakP,
                  value: s.dailyBreakGoalCount.toDouble(),
                  min: 1,
                  max: 30,
                  onChanged: (v) =>
                      repo.save(s.copyWith(dailyBreakGoalCount: v.round())),
                ),
                _GoalRow(
                  index: 3,
                  title: 'Weekly consistency',
                  effect:
                      'A day counts when you complete at least one break. '
                      'Looks at the last 7 days.',
                  current: '$activeDays',
                  target:
                      '${s.weeklyConsistencyTargetDays} day${s.weeklyConsistencyTargetDays == 1 ? '' : 's'}',
                  progress: weekP,
                  value: s.weeklyConsistencyTargetDays.toDouble(),
                  min: 1,
                  max: 7,
                  onChanged: (v) => repo.save(
                    s.copyWith(weeklyConsistencyTargetDays: v.round()),
                  ),
                  last: true,
                ),
                const SizedBox(height: 20),
                sectionHeader(
                  'App time budgets',
                  subtitle: s.appUsageTrackingEnabled
                      ? 'Soft daily limits per kind of app. A note shows in '
                            'your insights once you reach one. Nothing is '
                            'ever blocked.'
                      : 'Needs app usage tracking, which is off. Turn it on '
                            'in Privacy to use budgets.',
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

const _serif = ['Georgia', 'Times New Roman'];

/// Hairline used between goals instead of boxing each one in a card.
Widget _rule() =>
    Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle);

class _Summary extends StatelessWidget {
  final double overall;
  final int metCount;

  const _Summary({required this.overall, required this.metCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$metCount',
                style: TextStyle(
                  fontFamilyFallback: _serif,
                  fontSize: 52,
                  height: 1,
                  letterSpacing: -1.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'of 3 goals reached',
                style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: overall.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => _Hairline(value: v, height: 3),
          ),
          const SizedBox(height: 14),
          Text(
            'Targets to aim for. BreakMate tracks your progress but never '
            'blocks you or forces a break when you reach one.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat progress line: square ends, no rounded caps.
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
  final int index;
  final String title;
  final String effect;
  final String current;
  final String target;
  final double progress;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool last;

  const _GoalRow({
    required this.index,
    required this.title,
    required this.effect,
    required this.current,
    required this.target,
    required this.progress,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final met = progress >= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rule(),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '0$index',
                    style: TextStyle(
                      fontFamilyFallback: const ['Menlo', 'monospace'],
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (met)
                    Text(
                      'Reached',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.success,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    current,
                    style: TextStyle(
                      fontFamilyFallback: _serif,
                      fontSize: 30,
                      height: 1,
                      letterSpacing: -0.8,
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
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => _Hairline(value: v, met: met),
              ),
              const SizedBox(height: 12),
              Text(
                effect,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Target',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                  ),
                  const Spacer(),
                  _StepButton(
                    icon: Icons.remove,
                    tooltip: 'Decrease target',
                    onTap: value > min ? () => onChanged(value - 1) : null,
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      target,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamilyFallback: const ['Menlo', 'monospace'],
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    tooltip: 'Increase target',
                    onTap: value < max ? () => onChanged(value + 1) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (last) _rule(),
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
          width: 28,
          height: 28,
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
