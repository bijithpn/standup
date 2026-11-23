import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/presentation/widgets/custom_budget_dialog.dart';
import 'package:breakmate/features/settings/custom_budget_category.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Stepper UI for per-category daily time budgets (15-minute steps, max 4h); reports the full map via onChanged.
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
  final List<CustomBudgetCategory> customCategories;
  final ValueChanged<List<CustomBudgetCategory>>? onCustomChanged;

  const CategoryBudgetsCard({
    super.key,
    required this.budgetMinutes,
    required this.onChanged,
    this.customCategories = const [],
    this.onCustomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in _budgetableCategories)
          _buildRow(
            icon: category.icon,
            label: category.label,
            minutes: budgetMinutes[category.name] ?? 0,
            onMinutes: (m) => _setMinutes(category, m),
          ),
        for (final custom in customCategories)
          _buildRow(
            icon: custom.icon,
            label: custom.name,
            minutes: custom.minutes,
            onMinutes: (m) => _updateCustom(custom.copyWith(minutes: m)),
            actions: [
              _stepperButton(
                icon: CupertinoIcons.pencil,
                tooltip: 'Edit ${custom.name}',
                enabled: true,
                onPressed: () => _editCustom(context, custom),
              ),
              const SizedBox(width: 6),
              _stepperButton(
                icon: CupertinoIcons.delete,
                tooltip: 'Delete ${custom.name}',
                enabled: true,
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
      onCustomChanged?.call([...customCategories, created]);
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

  Widget _buildRow({
    required IconData icon,
    required String label,
    required int minutes,
    required ValueChanged<int> onMinutes,
    List<Widget> actions = const [],
  }) {
    final isSet = minutes > 0;
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
                child: Text(
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
              ),
              _stepperButton(
                icon: CupertinoIcons.minus,
                tooltip: 'Decrease $label budget',
                enabled: isSet,
                onPressed: () =>
                    onMinutes((minutes - _stepMinutes).clamp(0, _maxMinutes)),
              ),
              SizedBox(
                width: 76,
                child: Text(
                  isSet ? formatUsageDuration(minutes * 60) : 'Off',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFeatures: AppTheme.tabular,
                    fontFamilyFallback: const ['Menlo', 'monospace'],
                    fontSize: 13,
                    color: isSet ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                ),
              ),
              _stepperButton(
                icon: CupertinoIcons.plus,
                tooltip: 'Increase $label budget',
                enabled: minutes < _maxMinutes,
                onPressed: () =>
                    onMinutes((minutes + _stepMinutes).clamp(0, _maxMinutes)),
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
