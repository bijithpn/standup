import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/analytics/habits_summary.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

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
                  icon: CupertinoIcons.flame,
                  label: 'Break streak',
                  days: summary.breakStreakDays,
                ),
              ),
              SizedBox(
                height: 36,
                child: VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: AppTheme.separatorColor,
                ),
              ),
              Expanded(
                child: _StreakColumn(
                  icon: CupertinoIcons.bolt,
                  label: 'Focus streak',
                  days: summary.focusStreakDays,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 0.5, color: AppTheme.separatorColor),
          const SizedBox(height: 12),
          Text(
            summary.describe(),
            style: TextStyle(
              fontFeatures: AppTheme.tabular,
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
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
                Icon(icon, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '$days',
                  style: TextStyle(
                    fontFeatures: AppTheme.tabular,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  days == 1 ? ' day' : ' days',
                  style: TextStyle(
                    fontFeatures: AppTheme.tabular,
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFeatures: AppTheme.tabular,
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
