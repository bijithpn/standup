import 'package:flutter/cupertino.dart';
import 'package:breakmate/features/analytics/insights_overview.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

/// Renders [buildOverviewInsights]' findings as the first thing on the
/// Overview tab. Renders nothing when there's nothing worth saying yet
/// (new install, or a genuinely uneventful stretch) rather than an empty
/// card.
class InsightsOverviewCard extends StatelessWidget {
  final List<OverviewInsight> insights;

  /// Called with the transformed settings when the user taps an insight's
  /// "Apply" action (see [InsightAction]). Optional — insights without an
  /// action render without a button regardless.
  final ValueChanged<InsightAction>? onApply;

  const InsightsOverviewCard({
    super.key,
    required this.insights,
    this.onApply,
  });

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
              Icon(
                CupertinoIcons.sparkles,
                size: 18,
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Insights',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(insight.icon, size: 16, color: insight.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.text,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                if (insight.action != null && onApply != null) ...[
                  const SizedBox(height: 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      onPressed: () => onApply!(action),
      child: Text(
        action.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.accentColor,
        ),
      ),
    );
  }
}
