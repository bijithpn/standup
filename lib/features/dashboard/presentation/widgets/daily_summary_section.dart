import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class DailySummarySection extends StatelessWidget {
  const DailySummarySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StatsService>(
      builder: (context, statsService, child) {
        final stats = statsService.load();
        final todayStr = _todayString();
        final todayStats = stats.weeklyData.lastWhere(
          (d) => d.date == todayStr,
          orElse: () => DailyStats(
            date: todayStr,
            breaksCompleted: 0,
            breaksSkipped: 0,
            usageMinutes: 0,
          ),
        );

        final hasData =
            todayStats.breaksCompleted > 0 ||
            todayStats.breaksSkipped > 0 ||
            todayStats.usageMinutes > 0;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.todayActivity,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (hasData) _RecommendationChip(stats: stats),
                ],
              ),
              const SizedBox(height: 24),
              if (!hasData)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      AppStrings.noActivityRecorded,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                ValueListenableBuilder<Duration>(
                  valueListenable: sl<TimerEngine>().totalWorkTodayNotifier,
                  builder: (context, workToday, _) {
                    final hours = workToday.inHours;
                    final minutes = workToday.inMinutes % 60;
                    final seconds = workToday.inSeconds % 60;

                    String focusTimeStr;
                    if (hours > 0) {
                      focusTimeStr = '${hours}h ${minutes}m';
                    } else if (minutes > 0) {
                      focusTimeStr = '${minutes}m ${seconds}s';
                    } else {
                      focusTimeStr = '${seconds}s';
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: AppStrings.completed,
                          value: '${todayStats.breaksCompleted}',
                          color: AppTheme.success,
                        ),
                        _StatItem(
                          label: AppStrings.skipped,
                          value: '${todayStats.breaksSkipped}',
                          color: AppTheme.error,
                        ),
                        _StatItem(
                          label: AppStrings.focusTimeMins,
                          value: focusTimeStr,
                          color: AppTheme.warning,
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class _RecommendationChip extends StatelessWidget {
  final StatsModel stats;
  const _RecommendationChip({required this.stats});

  @override
  Widget build(BuildContext context) {
    String recommendation = 'Keep it up!';
    if (stats.completionRate < 0.5 && stats.breaksCompleted > 2) {
      recommendation = 'High skips. Try a longer interval?';
    } else if (stats.dailyUsageMinutes > 120 && stats.wellnessScore < 40) {
      recommendation = 'Intense day. Take a long break?';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        recommendation,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
