import 'package:breakmate/shared/widgets/minimal_controls.dart';
import '../settings/widgets/settings_group.dart';
import 'package:flutter/material.dart';
import '../settings/settings_repository.dart';
import '../settings/widgets/advanced_settings.dart';
import 'timing_suggestion.dart';
import 'timing_suggestion_dialog.dart';

class InterruptionFeedbackCard extends StatelessWidget {
  final SettingsRepository repository;
  const InterruptionFeedbackCard({super.key, required this.repository});
  @override
  Widget build(BuildContext context) => AdvancedSettings(
    title: 'Were these reminders well timed?',
    subtitle:
        'Optional feedback · review a suggestion before changing anything',
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 10,
        children: [
          MinimalButton(
            isSecondary: true,
            onPressed: () => showTimingSuggestion(
              context,
              TimingSuggestion.badTiming(repository.currentSettings),
              currentSettings: () => repository.currentSettings,
              onApply: repository.save,
            ),
            child: const Text('Bad timing'),
          ),
          MinimalButton(
            isSecondary: true,
            onPressed: () => showTimingSuggestion(
              context,
              TimingSuggestion.tooFrequent(repository.currentSettings),
              currentSettings: () => repository.currentSettings,
              onApply: repository.save,
            ),
            child: const Text('Too frequent'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Divider(height: 1, color: Theme.of(context).dividerColor),
      const SettingsNote(
        'Feedback stays on this device. Dismissing a suggestion leaves your settings unchanged.',
      ),
    ],
  );
}
