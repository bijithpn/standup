import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/analytics/habits_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Two streak numbers side by side, plus one sentence on whether they're in
/// sync — see [HabitsSummary]. Mirrors the card language of the companion
/// streak card and [InsightsOverviewCard] so it reads as part of the same
/// Overview tab, not a bolted-on widget.
class HabitsSummaryCard extends StatelessWidget {
  final HabitsSummary summary;

  const HabitsSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StreakColumn(
                  icon: CupertinoIcons.flame_fill,
                  label: 'Break streak',
                  days: summary.breakStreakDays,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppTheme.textMuted.withValues(alpha: 0.15),
              ),
              Expanded(
                child: _StreakColumn(
                  icon: CupertinoIcons.bolt_fill,
                  label: 'Focus streak',
                  days: summary.focusStreakDays,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppTheme.textMuted.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Text(
            summary.describe(),
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StreakColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int days;

  const _StreakColumn({
    required this.icon,
    required this.label,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $days ${days == 1 ? 'day' : 'days'}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: days > 0 ? AppTheme.accentColor : AppTheme.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  '$days',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  days == 1 ? ' day' : ' days',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
