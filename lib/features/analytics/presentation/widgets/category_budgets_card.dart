import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Opt-in, local-only daily time budgets per category — a soft nudge
/// threshold the user sets for themselves, never enforced by blocking
/// anything. Deliberately excludes [AppCategory.general] (a catch-all, not
/// a meaningful thing to budget) and [AppCategory.meeting] (meetings aren't
/// discretionary time to cap).
class CategoryBudgetsCard extends StatelessWidget {
  static const _budgetableCategories = [
    AppCategory.coding,
    AppCategory.writing,
    AppCategory.browsing,
    AppCategory.design,
  ];
  static const _stepMinutes = 15;
  static const _maxMinutes = 240;

  final Map<String, int> budgetMinutes;
  final ValueChanged<Map<String, int>> onChanged;

  const CategoryBudgetsCard({
    super.key,
    required this.budgetMinutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in _budgetableCategories)
          _buildRow(category, budgetMinutes[category.name] ?? 0),
        Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
      ],
    );
  }

  Widget _buildRow(AppCategory category, int minutes) {
    final isSet = minutes > 0;
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Icon(category.icon, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _stepperButton(
                icon: CupertinoIcons.minus,
                tooltip: 'Decrease ${category.label} budget',
                enabled: isSet,
                onPressed: () => _setMinutes(
                  category,
                  (minutes - _stepMinutes).clamp(0, _maxMinutes),
                ),
              ),
              SizedBox(
                width: 76,
                child: Text(
                  isSet ? formatUsageDuration(minutes * 60) : 'Off',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamilyFallback: const ['Menlo', 'monospace'],
                    fontSize: 13,
                    color: isSet ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                ),
              ),
              _stepperButton(
                icon: CupertinoIcons.plus,
                tooltip: 'Increase ${category.label} budget',
                enabled: minutes < _maxMinutes,
                onPressed: () => _setMinutes(
                  category,
                  (minutes + _stepMinutes).clamp(0, _maxMinutes),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onPressed : null,
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
            size: 13,
            color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  void _setMinutes(AppCategory category, int minutes) {
    final updated = Map<String, int>.from(budgetMinutes);
    if (minutes <= 0) {
      updated.remove(category.name);
    } else {
      updated[category.name] = minutes;
    }
    onChanged(updated);
  }
}
