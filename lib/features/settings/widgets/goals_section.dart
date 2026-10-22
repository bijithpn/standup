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
                _SummaryHero(overall: overall, metCount: metCount),
                const SizedBox(height: 16),
                _GoalCard(
                  icon: Icons.timer_outlined,
                  color: AppTheme.accent,
                  title: 'Daily focus time',
                  effect:
                      'Counts the time your work timer has run today. '
                      'Resets each morning.',
                  progressLabel:
                      '${_hm(worked)} of ${s.dailyWorkGoalHours}h today',
                  progress: focusP,
                  value: s.dailyWorkGoalHours.toDouble(),
                  min: 1,
                  max: 12,
                  valueLabel: '${s.dailyWorkGoalHours}h',
                  onChanged: (v) =>
                      repo.save(s.copyWith(dailyWorkGoalHours: v.round())),
                ),
                _GoalCard(
                  icon: Icons.self_improvement_rounded,
                  color: AppTheme.shortBreak,
                  title: 'Daily breaks',
                  effect:
                      'Counts breaks you complete (skipped ones don\'t). '
                      'Resets each morning.',
                  progressLabel:
                      '${stats.breaksCompleted} of ${s.dailyBreakGoalCount} today',
                  progress: breakP,
                  value: s.dailyBreakGoalCount.toDouble(),
                  min: 1,
                  max: 30,
                  valueLabel: '${s.dailyBreakGoalCount}',
                  onChanged: (v) =>
                      repo.save(s.copyWith(dailyBreakGoalCount: v.round())),
                ),
                _GoalCard(
                  icon: Icons.local_fire_department_outlined,
                  color: AppTheme.warning,
                  title: 'Weekly consistency',
                  effect:
                      'A day counts when you complete at least one break. '
                      'Looks at the last 7 days.',
                  progressLabel:
                      '$activeDays of ${s.weeklyConsistencyTargetDays} days',
                  progress: weekP,
                  value: s.weeklyConsistencyTargetDays.toDouble(),
                  min: 1,
                  max: 7,
                  valueLabel:
                      '${s.weeklyConsistencyTargetDays} day${s.weeklyConsistencyTargetDays == 1 ? '' : 's'}',
                  onChanged: (v) => repo.save(
                    s.copyWith(weeklyConsistencyTargetDays: v.round()),
                  ),
                ),
                sectionHeader(
                  'App time budgets',
                  subtitle: s.appUsageTrackingEnabled
                      ? 'Daily limits per kind of app. You get a gentle nudge '
                            'in your insights when one is exceeded.'
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

class _SummaryHero extends StatelessWidget {
  final double overall;
  final int metCount;

  const _SummaryHero({required this.overall, required this.metCount});

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent;
    final headline = metCount == 3
        ? 'All goals reached'
        : metCount == 0
        ? 'Let\'s get started'
        : '$metCount of 3 goals reached';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.22), AppTheme.surfaceCard],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: overall.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      color: metCount == 3 ? AppTheme.success : accent,
                      backgroundColor: AppTheme.border,
                    ),
                  ),
                  Text(
                    '${(v * 100).round()}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Targets to aim for. BreakMate tracks your progress but '
                  'never blocks you or forces a break when you reach one.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String effect;
  final String progressLabel;
  final double progress;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _GoalCard({
    required this.icon,
    required this.color,
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
    final tint = met ? AppTheme.success : color;
    final pct = (progress.clamp(0.0, 1.0) * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  met ? Icons.check_rounded : icon,
                  size: 22,
                  color: tint,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progressLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: tint,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  met ? 'Reached' : '$pct%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: tint,
                backgroundColor: AppTheme.border,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            effect,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, thickness: 0.5, color: AppTheme.separatorColor),
          Row(
            children: [
              Text(
                'Target',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              Expanded(
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: (max - min).round(),
                  label: valueLabel,
                  activeColor: color,
                  onChanged: onChanged,
                ),
              ),
              _StepButton(
                icon: Icons.remove_rounded,
                tooltip: 'Decrease target',
                onTap: value > min ? () => onChanged(value - 1) : null,
              ),
              SizedBox(
                width: 64,
                child: Text(
                  valueLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                tooltip: 'Increase target',
                onTap: value < max ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(
            icon,
            size: 16,
            color: onTap == null ? AppTheme.textMuted : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
