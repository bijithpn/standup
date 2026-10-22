import 'package:flutter/material.dart';

import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Today's time per category against the soft daily budgets set in Personal
/// Goals. Nothing is ever blocked. Renders nothing when no budget is set.
class DailyBudgetsCard extends StatelessWidget {
  const DailyBudgetsCard({
    super.key,
    required this.usedSecondsByCategory,
    required this.budgetMinutes,
  });

  final Map<AppCategory, int> usedSecondsByCategory;

  /// `AppCategory.name` -> minutes (0 or missing means no budget).
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Today's time against your soft limits (set in Personal Goals). "
            'Nothing is ever blocked.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
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
              Icon(category.icon, size: 15, color: category.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '${formatUsageDuration(usedSeconds)} of '
                '${formatUsageDuration(budgetSeconds)}'
                '${over ? '  ·  over' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: over ? AppTheme.warning : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 5,
              color: over ? AppTheme.warning : category.color,
              backgroundColor: AppTheme.border,
            ),
          ),
        ],
      ),
    );
  }
}
