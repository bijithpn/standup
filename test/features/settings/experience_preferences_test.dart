import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/experience_preferences.dart';
import 'package:breakmate/features/settings/exercise_model.dart';
import 'package:breakmate/features/settings/exercise_traits.dart';

void main() {
  test(
    'experience backup round trip preserves filters, rest and accessibility',
    () {
      const original = SettingsModel(
        experience: ExperiencePreferences(
          textScale: 1.3,
          highContrast: true,
          exercisePosition: 'seated',
          noEquipmentOnly: true,
          lowMovementOnly: true,
          avoidedAreas: ['neck', 'wrists'],
          restDays: [6, 7],
          restDates: ['2026-11-16'],
        ),
      );
      final restored = SettingsModel.fromMap(original.toMap());
      expect(restored.experience.toMap(), original.experience.toMap());
      expect(SettingsModel.fromMap({}).experience.textScale, 1);
    },
  );
  test(
    'malformed imports cannot introduce invalid scales or rest weekdays',
    () {
      final preferences = ExperiencePreferences.fromMap({
        'textScale': double.nan,
        'exercisePosition': 'flying',
        'restDays': [0, 9, 7, 7],
        'avoidedAreas': ['neck', 'unknown'],
      });
      expect(preferences.textScale, 1);
      expect(preferences.exercisePosition, 'any');
      expect(preferences.restDays, [7]);
      expect(preferences.avoidedAreas, ['neck']);
      expect(ExperiencePreferences.fromMap({'textScale': 20}).textScale, 1.5);
    },
  );
  test('combined filters exclude favorites and unknown custom activities', () {
    final pool = [
      ...ExerciseModel.defaults.map(
        (e) => e.copyWith(isFavorite: e.id == 'neck_stretch'),
      ),
      const ExerciseModel(
        id: 'custom_unknown',
        title: 'Unknown',
        durationSeconds: 30,
        category: ExerciseCategory.stretch,
        instructions: 'Custom instructions',
        isFavorite: true,
      ),
    ];
    const preferences = ExperiencePreferences(
      exercisePosition: 'seated',
      noEquipmentOnly: true,
      lowMovementOnly: true,
      avoidedAreas: ['neck', 'eyes', 'wrists', 'shoulders'],
    );
    for (var seed = 0; seed < 30; seed++) {
      final picked = ExerciseModel.pickForBreak(
        pool,
        Random(seed),
        preferences: preferences,
      )!;
      expect(['box_breathing', 'sigh_release'], contains(picked.id));
    }
  });
  test('equipment and position filters enforce the activity metadata', () {
    final wall = ExerciseModel.defaults.firstWhere((e) => e.id == 'wall_angel');
    final squat = ExerciseModel.defaults.firstWhere(
      (e) => e.id == 'desk_squats',
    );
    expect(
      ExerciseModel.pickForBreak(
        [wall, squat],
        Random(0),
        preferences: const ExperiencePreferences(noEquipmentOnly: true),
      ),
      isNull,
    );
    expect(
      ExerciseModel.pickForBreak(
        [wall],
        Random(0),
        preferences: const ExperiencePreferences(exercisePosition: 'seated'),
      ),
      isNull,
    );
  });
  test('empty match returns quiet rest rather than relaxing preferences', () {
    final neck = ExerciseModel.defaults.firstWhere(
      (e) => e.id == 'neck_stretch',
    );
    expect(
      ExerciseModel.pickForBreak(
        [neck],
        Random(0),
        preferences: const ExperiencePreferences(avoidedAreas: ['neck']),
      ),
      isNull,
    );
  });
  test(
    'custom activity metadata survives persistence and can match filters',
    () {
      const exercise = ExerciseModel(
        id: 'custom_rest',
        title: 'Quiet rest',
        durationSeconds: 20,
        category: ExerciseCategory.breathing,
        instructions: 'Rest quietly.',
        traits: ExerciseTraits(
          positions: ['seated'],
          equipmentRequired: false,
          lowMovement: true,
        ),
      );
      final restored = ExerciseModel.fromJson(exercise.toJson());
      expect(
        restored.effectiveTraits.matches(
          const ExperiencePreferences(
            exercisePosition: 'seated',
            lowMovementOnly: true,
          ),
        ),
        isTrue,
      );
    },
  );
}
