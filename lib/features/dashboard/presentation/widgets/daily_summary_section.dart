import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class DailySummarySection extends StatelessWidget {
  const DailySummarySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<StatsService, SettingsRepository>(
      builder: (context, statsService, settings, child) {
        final stats = statsService.load();
        final now = DateTime.now();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final done = stats.weeklyData
            .where((d) => d.date == todayStr)
            .fold<int>(0, (n, d) => n + d.breaksCompleted);
        final goal = settings.currentSettings.dailyBreakGoalCount;
        final restDay = settings.currentSettings.experience.isRestDay(now);

        final String? breaksDelta = restDay
            ? 'Rest day'
            : goal <= 0
            ? null
            : done >= goal
            ? 'Goal reached · $done / $goal'
            : '$done / $goal breaks';

        return ValueListenableBuilder<Duration>(
          valueListenable: sl<TimerEngine>().totalWorkTodayNotifier,
          builder: (context, workToday, _) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Stat(
                  label: 'Breaks today',
                  value: '$done',
                  delta: breaksDelta,
                ),
                _Stat(label: 'Focus time', value: _formatWork(workToday)),
                _Stat(
                  label: 'Streak',
                  value: '${stats.currentStreak}d',
                  delta: _streakDelta(stats),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String? _streakDelta(StatsModel stats) =>
      stats.longestStreak > stats.currentStreak
      ? 'Best ${stats.longestStreak}d'
      : null;

  static String _formatWork(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${d.inSeconds}s';
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;

  const _Stat({required this.label, required this.value, this.delta});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimary,
              fontFeatures: AppTheme.tabular,
            ),
          ),
          if (delta != null)
            Text(
              delta!,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontFeatures: AppTheme.tabular,
              ),
            ),
        ],
      ),
    );
  }
}
