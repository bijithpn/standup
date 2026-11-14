import 'settings_group.dart';
import 'package:flutter/material.dart';
import '../settings_model.dart';
import '../exercise_model.dart';
import '../experience_preferences.dart';
import 'settings_widgets.dart';

class ExercisePreferencesSection extends StatelessWidget {
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onSave;
  const ExercisePreferencesSection({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final preferences = settings.experience;
    void save(ExperiencePreferences value) =>
        onSave(settings.copyWith(experience: value));
    final exercises = settings.exercises.isEmpty
        ? ExerciseModel.defaults
        : settings.exercises;
    final matching = exercises
        .where((e) => e.isActive && e.effectiveTraits.matches(preferences))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader(
          'Exercises that suit you',
          subtitle:
              'Filters apply to guided breaks and Quick Stretch. While filters are active, breaks use a simple view with matching exercises or quiet rest.',
        ),
        SettingsGroup(
          children: [
            SettingsField(
              title: 'Position',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const {
                    'any': 'Any position',
                    'seated': 'Seated',
                    'standing': 'Standing',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: preferences.exercisePosition == entry.key,
                      onSelected: (_) => save(
                        preferences.copyWith(exercisePosition: entry.key),
                      ),
                    ),
                ],
              ),
            ),

            toggleRow(
              'No equipment',
              'Exclude exercises that need a wall, chair or other equipment.',
              preferences.noEquipmentOnly,
              (value) => save(preferences.copyWith(noEquipmentOnly: value)),
            ),
            toggleRow(
              'Low movement',
              'Prefer small movements and quiet rest activities.',
              preferences.lowMovementOnly,
              (value) => save(preferences.copyWith(lowMovementOnly: value)),
            ),
            SettingsField(
              title: 'Areas to avoid',
              description:
                  'Selected areas will be excluded from guided exercises.',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final area in ExperiencePreferences.bodyAreas)
                    FilterChip(
                      label: Text(
                        '${area[0].toUpperCase()}${area.substring(1)}',
                      ),
                      selected: preferences.avoidedAreas.contains(area),
                      onSelected: (selected) => save(
                        preferences.copyWith(
                          avoidedAreas: selected
                              ? [...preferences.avoidedAreas, area]
                              : preferences.avoidedAreas
                                    .where((item) => item != area)
                                    .toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SettingsField(
              title: 'Matching exercises',
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      matching.isEmpty
                          ? 'No matching exercises. Breaks will offer quiet rest; your filters will stay in place.'
                          : '${matching.length} matching exercises.',
                    ),
                    if (matching.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        matching.map((e) => e.title).join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.7,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
