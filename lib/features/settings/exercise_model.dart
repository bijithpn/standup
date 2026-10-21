import 'dart:convert';

enum ExerciseCategory { eyeRest, stretch, posture, breathing, movement }

class ExerciseModel {
  final String id;
  final String title;
  final int durationSeconds;
  final ExerciseCategory category;
  final String instructions;
  final bool enabled;
  final bool isFavorite;
  final bool isHidden;

  const ExerciseModel({
    required this.id,
    required this.title,
    required this.durationSeconds,
    required this.category,
    required this.instructions,
    this.enabled = true,
    this.isFavorite = false,
    this.isHidden = false,
  });

  ExerciseModel copyWith({
    String? id,
    String? title,
    int? durationSeconds,
    ExerciseCategory? category,
    String? instructions,
    bool? enabled,
    bool? isFavorite,
    bool? isHidden,
  }) {
    return ExerciseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      category: category ?? this.category,
      instructions: instructions ?? this.instructions,
      enabled: enabled ?? this.enabled,
      isFavorite: isFavorite ?? this.isFavorite,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'durationSeconds': durationSeconds,
    'category': category.name,
    'instructions': instructions,
    'enabled': enabled,
    'isFavorite': isFavorite,
    'isHidden': isHidden,
  };

  factory ExerciseModel.fromMap(Map<String, dynamic> map) => ExerciseModel(
    id: map['id'] as String,
    title: map['title'] as String,
    durationSeconds: map['durationSeconds'] as int,
    category: ExerciseCategory.values.firstWhere(
      (e) => e.name == map['category'],
      orElse: () => ExerciseCategory.stretch,
    ),
    instructions: map['instructions'] as String,
    enabled: map['enabled'] as bool? ?? true,
    isFavorite: map['isFavorite'] as bool? ?? false,
    isHidden: map['isHidden'] as bool? ?? false,
  );

  String toJson() => jsonEncode(toMap());
  factory ExerciseModel.fromJson(String source) =>
      ExerciseModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  static List<ExerciseModel> get defaults => [
    // Eye rest
    const ExerciseModel(
      id: 'eye_rest_20_20_20',
      title: '20-20-20 Eye Rest',
      durationSeconds: 20,
      category: ExerciseCategory.eyeRest,
      instructions:
          'Look at something 20 feet (6 meters) away for 20 seconds. '
          'Let your eyes relax and blink naturally.',
    ),
    const ExerciseModel(
      id: 'eye_palming',
      title: 'Palming',
      durationSeconds: 30,
      category: ExerciseCategory.eyeRest,
      instructions:
          'Rub your palms together to warm them, then gently cup them over '
          'closed eyes without pressing. Breathe slowly in the darkness.',
    ),
    const ExerciseModel(
      id: 'eye_focus_shift',
      title: 'Focus Shifting',
      durationSeconds: 30,
      category: ExerciseCategory.eyeRest,
      instructions:
          'Hold a thumb at arm\'s length, focus on it for 5 seconds, then '
          'shift focus to something far away for 5 seconds. Repeat 3 times.',
    ),
    const ExerciseModel(
      id: 'eye_blink_reset',
      title: 'Blink Reset',
      durationSeconds: 15,
      category: ExerciseCategory.eyeRest,
      instructions:
          'Close your eyes and blink slowly and fully 10 times. This '
          'rewets dry eyes from staring at a screen.',
    ),

    // Stretch
    const ExerciseModel(
      id: 'shoulder_rolls',
      title: 'Shoulder Rolls',
      durationSeconds: 30,
      category: ExerciseCategory.stretch,
      instructions:
          'Roll your shoulders backward in slow circles 5 times, '
          'then forward 5 times. Feel the tension release.',
    ),
    const ExerciseModel(
      id: 'neck_stretch',
      title: 'Neck Stretch',
      durationSeconds: 30,
      category: ExerciseCategory.stretch,
      instructions:
          'Slowly tilt your head to the right, hold 10 seconds. '
          'Return to center, then tilt left and hold 10 seconds.',
    ),
    const ExerciseModel(
      id: 'wrist_stretch',
      title: 'Wrist Stretch',
      durationSeconds: 20,
      category: ExerciseCategory.stretch,
      instructions:
          'Extend one arm, pull fingers back gently with the other hand. '
          'Hold 10 seconds each side.',
    ),
    const ExerciseModel(
      id: 'side_stretch',
      title: 'Side Reach',
      durationSeconds: 30,
      category: ExerciseCategory.stretch,
      instructions:
          'Raise one arm overhead and lean gently to the opposite side. '
          'Hold 10 seconds, then switch sides.',
    ),
    const ExerciseModel(
      id: 'upper_back_stretch',
      title: 'Upper Back Stretch',
      durationSeconds: 25,
      category: ExerciseCategory.stretch,
      instructions:
          'Clasp your hands in front of you, round your upper back, and '
          'push your palms forward. Hold 10 seconds, then release.',
    ),
    const ExerciseModel(
      id: 'finger_stretch',
      title: 'Finger Stretch',
      durationSeconds: 20,
      category: ExerciseCategory.stretch,
      instructions:
          'Spread your fingers wide apart, hold 5 seconds, then make a '
          'loose fist. Repeat 5 times to ease typing fatigue.',
    ),

    // Posture
    const ExerciseModel(
      id: 'posture_reset',
      title: 'Posture Reset',
      durationSeconds: 20,
      category: ExerciseCategory.posture,
      instructions:
          'Sit tall, pull your shoulder blades back and down, and tuck '
          'your chin slightly. Hold for 10 seconds and relax.',
    ),
    const ExerciseModel(
      id: 'chin_tuck',
      title: 'Chin Tucks',
      durationSeconds: 20,
      category: ExerciseCategory.posture,
      instructions:
          'Gently draw your chin straight back, as if making a double '
          'chin, to counter forward head posture. Repeat 8 times.',
    ),
    const ExerciseModel(
      id: 'wall_angel',
      title: 'Wall Angels',
      durationSeconds: 35,
      category: ExerciseCategory.posture,
      instructions:
          'Stand with your back against a wall, arms bent like goalposts. '
          'Slide them up and down slowly, keeping contact with the wall.',
    ),

    // Breathing
    const ExerciseModel(
      id: 'stand_and_breathe',
      title: 'Stand & Breathe',
      durationSeconds: 30,
      category: ExerciseCategory.breathing,
      instructions:
          'Stand up, place hands on your belly. '
          'Breathe in for 4 counts, hold 2, out for 6. Repeat 3 times.',
    ),
    const ExerciseModel(
      id: 'box_breathing',
      title: 'Box Breathing',
      durationSeconds: 40,
      category: ExerciseCategory.breathing,
      instructions:
          'Inhale for 4 counts, hold for 4, exhale for 4, hold for 4. '
          'Repeat the square pattern to calm a racing mind.',
    ),
    const ExerciseModel(
      id: 'sigh_release',
      title: 'Physiological Sigh',
      durationSeconds: 20,
      category: ExerciseCategory.breathing,
      instructions:
          'Take two quick inhales through the nose (one long, one short), '
          'then a slow, long exhale through the mouth. Repeat 3 times.',
    ),

    // Movement
    const ExerciseModel(
      id: 'quick_walk',
      title: 'Quick Walk',
      durationSeconds: 60,
      category: ExerciseCategory.movement,
      instructions:
          'Get up and walk around your space for a minute — to a window, '
          'another room, or just pace. Fresh blood flow, fresh focus.',
    ),
    const ExerciseModel(
      id: 'calf_raises',
      title: 'Calf Raises',
      durationSeconds: 30,
      category: ExerciseCategory.movement,
      instructions:
          'Stand up and rise onto your toes, then lower slowly. '
          'Repeat 15 times to wake up your legs after sitting.',
    ),
    const ExerciseModel(
      id: 'desk_squats',
      title: 'Desk Squats',
      durationSeconds: 30,
      category: ExerciseCategory.movement,
      instructions:
          'Stand in front of your chair, lower into a squat until you '
          'nearly sit, then stand back up. Repeat 10 times.',
    ),
  ];
}
