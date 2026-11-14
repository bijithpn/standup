import '../../../settings/widgets/settings_group.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import '../../weekly_actionable_insight.dart';
import '../../stats_service.dart' show DailyStats;
import '../../../settings/settings_model.dart';
import '../../../feedback/timing_suggestion_dialog.dart';

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
    return SettingsGroup(
      margin: const EdgeInsets.only(top: 20, bottom: 8),
      children: [
        SettingsField(
          title: 'One thing from this week',
          child: Text(
            insight.observation,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (insight.suggestion != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: OutlinedButton(
              onPressed: () => showTimingSuggestion(
                context,
                insight.suggestion,
                currentSettings: currentSettings,
                onApply: onApply,
              ),
              child: const Text('Review suggested adjustment'),
            ),
          ),
      ],
    );
  }
}
