import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/analytics/context_switch_tracker.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/break_history_service.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// "Break activity" on the front page: how today's breaks are going against
/// the daily goal, what happened and when, and how long you have worked.
class DailySummarySection extends StatelessWidget {
  const DailySummarySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<StatsService, BreakHistoryService, SettingsRepository>(
      builder: (context, statsService, history, settings, child) {
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

        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final events = history.eventsBetween(startOfDay, now)
          ..sort((a, b) => a.time.compareTo(b.time));

        final goal = settings.currentSettings.dailyBreakGoalCount;
        final done = todayStats.breaksCompleted;
        final skipped = todayStats.breaksSkipped;
        final total = done + skipped;
        final hasData = total > 0 || todayStats.usageMinutes > 0;
        final rate = total == 0 ? null : (done / total * 100).round();

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Break activity',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _GoalChip(done: done, goal: goal),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: goal <= 0 ? 0 : (done / goal).clamp(0.0, 1.0),
                  minHeight: 4,
                  color: done >= goal ? AppTheme.success : AppTheme.textPrimary,
                  backgroundColor: AppTheme.border,
                ),
              ),
              const SizedBox(height: 22),
              if (!hasData)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No breaks yet today. Your first one will show up here.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else ...[
                ValueListenableBuilder<Duration>(
                  valueListenable: sl<TimerEngine>().totalWorkTodayNotifier,
                  builder: (context, workToday, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: AppStrings.completed,
                          value: '$done',
                          color: AppTheme.textPrimary,
                        ),
                        _StatItem(
                          label: AppStrings.skipped,
                          value: '$skipped',
                          color: AppTheme.textPrimary,
                        ),
                        _StatItem(
                          label: 'Kept',
                          value: rate == null ? '–' : '$rate%',
                          color: AppTheme.textPrimary,
                        ),
                        _StatItem(
                          label: 'Worked',
                          value: _formatWork(workToday),
                          color: AppTheme.textPrimary,
                        ),
                      ],
                    );
                  },
                ),
                if (events.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    'Timeline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e
                          in events.reversed.take(12).toList().reversed)
                        _EventChip(event: e),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                _RecommendationChip(stats: stats),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _formatWork(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${d.inSeconds}s';
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class _GoalChip extends StatelessWidget {
  final int done;
  final int goal;
  const _GoalChip({required this.done, required this.goal});

  @override
  Widget build(BuildContext context) {
    final met = done >= goal && goal > 0;
    return Text(
      met ? 'Goal reached · $done / $goal' : '$done / $goal breaks',
      style: TextStyle(
        fontFamilyFallback: const ['Menlo', 'monospace'],
        fontSize: 12,
        color: met ? AppTheme.success : AppTheme.textSecondary,
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  final BreakEvent event;
  const _EventChip({required this.event});

  @override
  Widget build(BuildContext context) {
    final ok = event.completed;
    final color = ok ? AppTheme.success : AppTheme.error;
    final h = event.time.hour.toString().padLeft(2, '0');
    final m = event.time.minute.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            '$h:$m',
            style: TextStyle(
              fontFamilyFallback: const ['Menlo', 'monospace'],
              fontSize: 12,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationChip extends StatelessWidget {
  final StatsModel stats;
  const _RecommendationChip({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Consumer<ContextSwitchTracker>(
      builder: (context, switchTracker, _) {
        final switchCount = switchTracker.switchesInWindow(DateTime.now());
        return _buildChip(_recommendationFor(switchCount));
      },
    );
  }

  /// Context-switch fragmentation takes priority when it's high — it's a
  /// live, actionable signal (see [ContextSwitchTracker]) — otherwise falls
  /// back to the existing skip-rate / intense-day heuristics. Purely
  /// informational: it never changes break timing on its own.
  String _recommendationFor(int switchCount) {
    if (switchCount >= 12) {
      return "$switchCount app switches in the last hour — a short break might help you refocus.";
    }
    if (stats.completionRate < 0.5 && stats.breaksCompleted > 2) {
      return 'High skips. Try a longer interval?';
    }
    if (stats.dailyUsageMinutes > 120 && stats.wellnessScore < 40) {
      return 'Intense day. Take a long break?';
    }
    return 'Keep it up!';
  }

  Widget _buildChip(String recommendation) {
    return Text(
      recommendation,
      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
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
            fontFamilyFallback: const ['Georgia', 'Times New Roman'],
            fontSize: 34,
            color: AppTheme.textPrimary,
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
