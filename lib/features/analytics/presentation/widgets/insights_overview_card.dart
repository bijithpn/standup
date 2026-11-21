import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/analytics/insights_overview.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

class InsightsOverviewCard extends StatelessWidget {
  final List<OverviewInsight> insights;

  final ValueChanged<InsightAction>? onApply;

  const InsightsOverviewCard({super.key, required this.insights, this.onApply});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Insights',
                style: TextStyle(
                  fontFeatures: AppTheme.tabular,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final insight in insights) _buildRow(insight),
        ],
      ),
    );
  }

  Widget _buildRow(OverviewInsight insight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(insight.icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.text,
                  style: TextStyle(
                    fontFeatures: AppTheme.tabular,
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (insight.action != null && onApply != null) ...[
                  const SizedBox(height: 8),
                  _buildApplyButton(insight.action!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyButton(InsightAction action) {
    return MinimalButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onPressed: () => onApply!(action),
      child: Text(
        action.label,
        style: TextStyle(
          fontFeatures: AppTheme.tabular,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.accentColor,
        ),
      ),
    );
  }
}
