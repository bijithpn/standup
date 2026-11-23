import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import '../../weekly_actionable_insight.dart';
import '../../stats_service.dart' show DailyStats;
import '../../../settings/settings_model.dart';
import '../../../feedback/timing_suggestion_dialog.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class WeeklyActionableInsightCard extends StatelessWidget {
  final List<DailyStats> days;
  final SettingsModel settings;
  final SettingsModel Function() currentSettings;
  final Future<void> Function(SettingsModel) onApply;
  const WeeklyActionableInsightCard({
    super.key,
    required this.days,
    required this.settings,
    required this.currentSettings,
    required this.onApply,
  });
  @override
  Widget build(BuildContext context) {
    final insight = WeeklyActionableInsight.fromDays(
      days,
      settings,
      clock.now(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'One thing from this week',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            insight.observation,
            style: TextStyle(
              fontFeatures: AppTheme.tabular,
              fontSize: 16,
              height: 1.5,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (insight.suggestion != null) ...[
          const SizedBox(height: AppTheme.space12),
          TextButton(
            onPressed: () => showTimingSuggestion(
              context,
              insight.suggestion,
              currentSettings: currentSettings,
              onApply: onApply,
            ),
            child: const Text('Review adjustment'),
          ),
        ],
      ],
    );
  }
}
