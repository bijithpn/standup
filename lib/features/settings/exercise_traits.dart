import 'experience_preferences.dart';

/// Descriptive activity metadata. Unknown custom exercises stay out of restricted selections.
class ExerciseTraits {
  final List<String> positions;
  final bool? equipmentRequired;
  final bool? lowMovement;
  final List<String> areas;
  const ExerciseTraits({
    this.positions = const [],
    this.equipmentRequired,
    this.lowMovement,
    this.areas = const [],
  });

  bool matches(ExperiencePreferences preferences) {
    if (!preferences.hasExerciseRestrictions) return true;
    if (positions.isEmpty || equipmentRequired == null || lowMovement == null) {
      return false;
    }
    return (preferences.exercisePosition == 'any' ||
            positions.contains(preferences.exercisePosition)) &&
        (!preferences.noEquipmentOnly || equipmentRequired == false) &&
        (!preferences.lowMovementOnly || lowMovement == true) &&
        !areas.any(preferences.avoidedAreas.contains);
  }

  Map<String, dynamic> toMap() => {
    'positions': positions,
    'equipmentRequired': equipmentRequired,
    'lowMovement': lowMovement,
    'areas': areas,
  };
  factory ExerciseTraits.fromMap(Map map) => ExerciseTraits(
    positions: (map['positions'] as List? ?? []).whereType<String>().toList(),
    equipmentRequired: map['equipmentRequired'] as bool?,
    lowMovement: map['lowMovement'] as bool?,
    areas: (map['areas'] as List? ?? []).whereType<String>().toList(),
  );

  static ExerciseTraits forId(String id) {
    const both = ['seated', 'standing'];
    return switch (id) {
      'eye_rest_20_20_20' || 'eye_blink_reset' => const ExerciseTraits(
        positions: both,
        equipmentRequired: false,
        lowMovement: true,
        areas: ['eyes'],
      ),
      'eye_palming' || 'eye_focus_shift' => const ExerciseTraits(
        positions: both,
        equipmentRequired: false,
        lowMovement: true,
        areas: ['eyes', 'wrists', 'shoulders'],
      ),
      'shoulder_rolls' => const ExerciseTraits(
        positions: both,
        equipmentRequired: false,
        lowMovement: true,
        areas: ['shoulders'],
      ),
      'neck_stretch' || 'chin_tuck' => const ExerciseTraits(
        positions: both,
        equipmentRequired: false,
        lowMovement: true,
        areas: ['neck'],
      ),
      'wrist_stretch' || 'finger_stretch' => const ExerciseTraits(
        positions: both,
        equipmentRequired: false,
        lowMovement: true,
        areas: ['wrists'],
      ),
      'side_stretch' || 'upper_back_stretch' => const ExerciseTraits(
        positions: both,
        equipmentRequired: false,
        lowMovement: false,
        areas: ['back', 'shoulders'],
      ),
      'posture_reset' => const ExerciseTraits(
        positions: ['seated'],
        equipmentRequired: false,
        lowMovement: true,
        areas: ['neck', 'back', 'shoulders'],
      ),
      'wall_angel' => const ExerciseTraits(
        positions: ['standing'],
        equipmentRequired: true,
        lowMovement: false,
        areas: ['shoulders', 'back'],
      ),
      'stand_and_breathe' => const ExerciseTraits(
        positions: ['standing'],
        equipmentRequired: false,
        lowMovement: true,
      ),
      'box_breathing' || 'sigh_release' => const ExerciseTraits(
        positions: both,
        equipmentRequired: false,
        lowMovement: true,
      ),
      'quick_walk' => const ExerciseTraits(
        positions: ['standing'],
        equipmentRequired: false,
        lowMovement: false,
        areas: ['knees', 'ankles'],
      ),
      'calf_raises' => const ExerciseTraits(
        positions: ['standing'],
        equipmentRequired: false,
        lowMovement: false,
        areas: ['ankles'],
      ),
      'desk_squats' => const ExerciseTraits(
        positions: ['standing'],
        equipmentRequired: true,
        lowMovement: false,
        areas: ['back', 'knees', 'ankles'],
      ),
      _ => const ExerciseTraits(),
    };
  }
}
