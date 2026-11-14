import 'settings_group.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import '../settings_model.dart';
import '../experience_preferences.dart';
import 'settings_widgets.dart';

class RestDaySettings extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;
  const RestDaySettings({
    super.key,
    required this.settings,
    required this.onSave,
  });
  @override
  Widget build(BuildContext context) {
    final preferences = settings.experience;
    final today = ExperiencePreferences.dateKey(clock.now());
    final marked = preferences.restDates.contains(today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Make room for rest',
          subtitle:
              'Rest days reduce your weekly target and remove daily goal pressure. Reminder schedules stay under Working Hours.',
        ),
        SettingsGroup(
          children: [
            SettingsField(
              title: 'Weekly rest days',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const {
                    1: 'Mon',
                    2: 'Tue',
                    3: 'Wed',
                    4: 'Thu',
                    5: 'Fri',
                    6: 'Sat',
                    7: 'Sun',
                  }.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: preferences.restDays.contains(entry.key),
                      onSelected: (selected) => onSave(
                        settings.copyWith(
                          experience: preferences.copyWith(
                            restDays: selected
                                ? [...preferences.restDays, entry.key]
                                : preferences.restDays
                                      .where((day) => day != entry.key)
                                      .toList(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SettingsField(
              title: 'Today',
              child: OutlinedButton(
                onPressed: () => onSave(
                  settings.copyWith(
                    experience: preferences.copyWith(
                      restDates: marked
                          ? preferences.restDates
                                .where((date) => date != today)
                                .toList()
                          : [...preferences.restDates, today],
                    ),
                  ),
                ),
                child: Text(
                  marked ? 'Undo today’s rest day' : 'Take today as a rest day',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
