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
      id: 'stand_and_breathe',
      title: 'Stand & Breathe',
      durationSeconds: 30,
      category: ExerciseCategory.breathing,
      instructions:
          'Stand up, place hands on your belly. '
          'Breathe in for 4 counts, hold 2, out for 6. Repeat 3 times.',
    ),
  ];
}
