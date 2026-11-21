import 'package:flutter/material.dart';

import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class DailyBudgetsCard extends StatelessWidget {
  const DailyBudgetsCard({
    super.key,
    required this.usedSecondsByCategory,
    required this.budgetMinutes,
  });

  final Map<AppCategory, int> usedSecondsByCategory;

  final Map<String, int> budgetMinutes;

  @override
  Widget build(BuildContext context) {
    final budgets = {
      for (final e in budgetMinutes.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (budgets.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily budgets',
            style: TextStyle(
              fontFeatures: AppTheme.tabular,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Soft limits from Personal Goals. Nothing is blocked.',
            style: TextStyle(
              fontFeatures: AppTheme.tabular,
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          for (final category in AppCategory.values)
            if (budgets.containsKey(category.name))
              _row(
                category,
                usedSecondsByCategory[category] ?? 0,
                budgets[category.name]! * 60,
              ),
        ],
      ),
    );
  }

  Widget _row(AppCategory category, int usedSeconds, int budgetSeconds) {
    final ratio = usedSeconds / budgetSeconds;
    final over = ratio >= 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.label,
                  style: TextStyle(
                    fontFeatures: AppTheme.tabular,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '${formatUsageDuration(usedSeconds)} of '
                '${formatUsageDuration(budgetSeconds)}'
                '${over ? '  ·  over' : ''}',
                style: TextStyle(
                  fontFeatures: AppTheme.tabular,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: over ? AppTheme.warning : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 4,
              color: over ? AppTheme.warning : AppTheme.textMuted,
              backgroundColor: AppTheme.border,
            ),
          ),
        ],
      ),
    );
  }
}
