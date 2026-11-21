import 'settings_group.dart';
import 'package:flutter/material.dart';
import '../settings_model.dart';
import 'settings_widgets.dart';

class AccessibilitySettings extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;
  const AccessibilitySettings({
    super.key,
    required this.settings,
    required this.onSave,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      sectionHeader('Accessibility'),
      SettingsGroup(
        children: [
          SettingsField(
            title: 'Text size',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final scale in [1.0, 1.15, 1.3, 1.5])
                  ChoiceChip(
                    label: Text('${(scale * 100).round()}%'),
                    selected: settings.experience.textScale == scale,
                    onSelected: (_) => onSave(
                      settings.copyWith(
                        experience: settings.experience.copyWith(
                          textScale: scale,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          toggleRow(
            'High contrast',
            'Stronger text and borders, plain break background',
            settings.experience.highContrast,
            (value) => onSave(
              settings.copyWith(
                experience: settings.experience.copyWith(highContrast: value),
              ),
            ),
          ),
          toggleRow(
            'Reduce motion',
            'Stops decorative loops. Timers still run',
            settings.reduceMotion,
            (value) => onSave(
              settings.copyWith(
                reduceMotion: value,
                companionReducedMotion: value,
              ),
            ),
          ),
          const SettingsNote(
            'Tab moves between controls, Space activates, Escape closes a skippable break. Larger text uses a simple, scrollable break view.',
          ),
        ],
      ),
    ],
  );
}
