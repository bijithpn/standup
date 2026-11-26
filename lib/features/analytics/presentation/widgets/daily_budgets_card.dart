import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:breakmate/features/analytics/app_usage_models.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_cards.dart';
import 'package:breakmate/features/analytics/presentation/productivity/productivity_format.dart'
    show appColor;
import 'package:breakmate/features/settings/custom_budget_category.dart';
import 'package:breakmate/features/wellness/domain/app_categorizer.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class _Budget {
  const _Budget(this.icon, this.label, this.used, this.limit);

  final IconData icon;
  final String label;
  final int used;
  final int limit;
}

/// Budgets as compact ring tiles, each showing its share of the user's office day.
class DailyBudgetsCard extends StatelessWidget {
  const DailyBudgetsCard({
    super.key,
    required this.usedSecondsByCategory,
    required this.budgetMinutes,
    this.workDaySeconds = 0,
    this.customCategories = const [],
    this.customUsedSeconds = const {},
  });

  final Map<AppCategory, int> usedSecondsByCategory;

  final Map<String, int> budgetMinutes;

  final int workDaySeconds;

  final List<CustomBudgetCategory> customCategories;

  final Map<String, int> customUsedSeconds;

  @override
  Widget build(BuildContext context) {
    final budgets = <_Budget>[
      for (final category in AppCategory.values)
        if ((budgetMinutes[category.name] ?? 0) > 0)
          _Budget(
            category.icon,
            category.label,
            usedSecondsByCategory[category] ?? 0,
            budgetMinutes[category.name]! * 60,
          ),
      for (final custom in customCategories)
        if (custom.minutes > 0)
          _Budget(
            custom.icon,
            custom.name,
            customUsedSeconds[custom.id] ?? 0,
            custom.minutes * 60,
          ),
    ];
    if (budgets.isEmpty) return const SizedBox.shrink();

    final allocated = budgets.fold<int>(0, (a, b) => a + b.limit);
    final dayTotal = workDaySeconds > allocated ? workDaySeconds : allocated;

    return ProductivitySection(
      title: 'Daily budgets',
      subtitle: workDaySeconds > 0
          ? 'Slices of your ${formatUsageDuration(workDaySeconds)} office day. '
                'Nothing is blocked.'
          : 'Soft limits from Personal Goals. Nothing is blocked.',
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 12.0;
          const minTile = 200.0;
          final columns = math.max(
            1,
            ((box.maxWidth + gap) / (minTile + gap)).floor(),
          );
          final width = (box.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < budgets.length; i++)
                SizedBox(
                  width: width,
                  child: _Tile(
                    budget: budgets[i],
                    colour: appColor(i),
                    dayShare: (budgets[i].limit * 100 / dayTotal).round(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.budget,
    required this.colour,
    required this.dayShare,
  });

  final _Budget budget;
  final Color colour;
  final int dayShare;

  @override
  Widget build(BuildContext context) {
    final over = budget.used >= budget.limit;
    final ringColour = over ? AppTheme.warning : colour;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CustomPaint(
              painter: _RingPainter(
                fraction: budget.used / budget.limit,
                colour: ringColour,
                track: AppTheme.border,
              ),
              child: Center(
                child: Icon(budget.icon, size: 18, color: ringColour),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  budget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFeatures: AppTheme.tabular,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatUsageDuration(budget.used)} of '
                  '${formatUsageDuration(budget.limit)}',
                  style: TextStyle(
                    fontFeatures: AppTheme.tabular,
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  over ? 'Over budget' : '$dayShare% of day',
                  style: TextStyle(
                    fontFeatures: AppTheme.tabular,
                    fontSize: 11,
                    color: over ? AppTheme.warning : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.colour,
    required this.track,
  });

  final double fraction;
  final Color colour;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    final sweep = math.pi * 2 * fraction.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(rect, -math.pi / 2, sweep, false, paint..color = colour);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.colour != colour || old.track != track;
}
