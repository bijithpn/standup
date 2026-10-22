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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Set a soft daily budget per category. A note appears once you '
              'reach it — nothing is ever blocked.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          for (final category in _budgetableCategories)
            _buildRow(category, budgetMinutes[category.name] ?? 0),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildRow(AppCategory category, int minutes) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(category.icon, size: 16, color: category.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          _buildStepper(category, minutes),
        ],
      ),
    );
  }

  Widget _buildStepper(AppCategory category, int minutes) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperButton(
          icon: CupertinoIcons.minus,
          enabled: minutes > 0,
          onPressed: () => _setMinutes(
            category,
            (minutes - _stepMinutes).clamp(0, _maxMinutes),
          ),
        ),
        SizedBox(
          width: 76,
          child: Text(
            minutes <= 0 ? 'No budget' : formatUsageDuration(minutes * 60),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: minutes > 0 ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
        ),
        _stepperButton(
          icon: CupertinoIcons.plus,
          enabled: minutes < _maxMinutes,
          onPressed: () => _setMinutes(
            category,
            (minutes + _stepMinutes).clamp(0, _maxMinutes),
          ),
        ),
      ],
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 14,
        icon: Icon(
          icon,
          color: enabled ? AppTheme.accentColor : AppTheme.textMuted,
        ),
        onPressed: enabled ? onPressed : null,
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
