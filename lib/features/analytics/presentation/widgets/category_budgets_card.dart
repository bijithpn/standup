import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/presentation/widgets/custom_budget_dialog.dart';
import 'package:breakmate/features/settings/custom_budget_category.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Stepper UI for per-category daily time budgets (15-minute steps) that together fit inside the office day.
class CategoryBudgetsCard extends StatelessWidget {
  static const _budgetableCategories = [
    AppCategory.coding,
    AppCategory.writing,
    AppCategory.browsing,
    AppCategory.design,
  ];
  static const _stepMinutes = 15;
  static const _maxOfficeHours = 16;

  final Map<String, int> budgetMinutes;
  final ValueChanged<Map<String, int>> onChanged;
  final List<CustomBudgetCategory> customCategories;
  final ValueChanged<List<CustomBudgetCategory>>? onCustomChanged;

  final int officeHours;
  final ValueChanged<int> onOfficeHoursChanged;

  const CategoryBudgetsCard({
    super.key,
    required this.officeHours,
    required this.onOfficeHoursChanged,
    required this.budgetMinutes,
    required this.onChanged,
    this.customCategories = const [],
    this.onCustomChanged,
  });

  int get _allocated =>
      budgetMinutes.values.fold(0, (a, b) => a + b) +
      customCategories.fold(0, (a, c) => a + c.minutes);

  int get _remaining => officeHours * 60 - _allocated;

  /// One step up, shortened to whatever is left of the office day.
  int _raised(int minutes) => minutes + math.min(_stepMinutes, _remaining);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRow(
          icon: CupertinoIcons.briefcase,
          label: 'Office hours',
          detail: _remaining < 0
              ? '${formatUsageDuration(-_remaining * 60)} over. Lower a budget'
              : '${formatUsageDuration(_remaining * 60)} left to budget',
          value: '${officeHours}h',
          decreaseTooltip: 'Decrease office hours',
          increaseTooltip: 'Increase office hours',
          onDecrease: officeHours > 1 && (officeHours - 1) * 60 >= _allocated
              ? () => onOfficeHoursChanged(officeHours - 1)
              : null,
          onIncrease: officeHours < _maxOfficeHours
              ? () => onOfficeHoursChanged(officeHours + 1)
              : null,
        ),
        for (final category in _budgetableCategories)
          _budgetRow(
            icon: category.icon,
            label: category.label,
            minutes: budgetMinutes[category.name] ?? 0,
            onMinutes: (m) => _setMinutes(category, m),
          ),
        for (final custom in customCategories)
          _budgetRow(
            icon: custom.icon,
            label: custom.name,
            minutes: custom.minutes,
            onMinutes: (m) => _updateCustom(custom.copyWith(minutes: m)),
            actions: [
              _stepperButton(
                icon: CupertinoIcons.pencil,
                tooltip: 'Edit ${custom.name}',
                onPressed: () => _editCustom(context, custom),
              ),
              const SizedBox(width: 6),
              _stepperButton(
                icon: CupertinoIcons.delete,
                tooltip: 'Delete ${custom.name}',
                onPressed: () => onCustomChanged?.call([
                  for (final c in customCategories)
                    if (c.id != custom.id) c,
                ]),
              ),
            ],
          ),
        Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
        if (onCustomChanged != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MinimalButton(
                isSecondary: true,
                onPressed: () => _addCustom(context),
                child: const Text('Add budget type'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addCustom(BuildContext context) async {
    final created = await showCustomBudgetDialog(context);
    if (created != null) {
      final minutes = math.max(0, math.min(created.minutes, _remaining));
      onCustomChanged?.call([
        ...customCategories,
        created.copyWith(minutes: minutes),
      ]);
    }
  }

  Future<void> _editCustom(
    BuildContext context,
    CustomBudgetCategory custom,
  ) async {
    final edited = await showCustomBudgetDialog(context, existing: custom);
    if (edited != null) _updateCustom(edited);
  }

  void _updateCustom(CustomBudgetCategory updated) {
    onCustomChanged?.call([
      for (final c in customCategories) c.id == updated.id ? updated : c,
    ]);
  }

  Widget _budgetRow({
    required IconData icon,
    required String label,
    required int minutes,
    required ValueChanged<int> onMinutes,
    List<Widget> actions = const [],
  }) {
    return _buildRow(
      icon: icon,
      label: label,
      value: minutes > 0 ? formatUsageDuration(minutes * 60) : 'Off',
      muted: minutes <= 0,
      decreaseTooltip: 'Decrease $label budget',
      increaseTooltip: 'Increase $label budget',
      onDecrease: minutes > 0
          ? () => onMinutes(math.max(0, minutes - _stepMinutes))
          : null,
      onIncrease: _remaining > 0 ? () => onMinutes(_raised(minutes)) : null,
      actions: actions,
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String label,
    required String value,
    required String decreaseTooltip,
    required String increaseTooltip,
    required VoidCallback? onDecrease,
    required VoidCallback? onIncrease,
    String? detail,
    bool muted = false,
    List<Widget> actions = const [],
  }) {
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFeatures: AppTheme.tabular,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: TextStyle(
                          fontFeatures: AppTheme.tabular,
                          fontSize: 12,
                          color: _remaining < 0
                              ? AppTheme.warning
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _stepperButton(
                icon: CupertinoIcons.minus,
                tooltip: decreaseTooltip,
                onPressed: onDecrease,
              ),
              SizedBox(
                width: 76,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFeatures: AppTheme.tabular,
                    fontFamilyFallback: const ['Menlo', 'monospace'],
                    fontSize: 13,
                    color: muted ? AppTheme.textMuted : AppTheme.textPrimary,
                  ),
                ),
              ),
              _stepperButton(
                icon: CupertinoIcons.plus,
                tooltip: increaseTooltip,
                onPressed: onIncrease,
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 14),
                ...actions,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
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
            color: onPressed == null
                ? AppTheme.textMuted
                : AppTheme.textPrimary,
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
