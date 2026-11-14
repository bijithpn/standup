/// Preferences added independently of the legacy settings snapshot schema.
class ExperiencePreferences {
  final double textScale;
  final bool highContrast;
  final String exercisePosition;
  final bool noEquipmentOnly;
  final bool lowMovementOnly;
  final List<String> avoidedAreas;
  final List<int> restDays;
  final List<String> restDates;
  final bool companionEscalates;

  const ExperiencePreferences({
    this.textScale = 1,
    this.highContrast = false,
    this.exercisePosition = 'any',
    this.noEquipmentOnly = false,
    this.lowMovementOnly = false,
    this.avoidedAreas = const [],
    this.restDays = const [],
    this.restDates = const [],
    this.companionEscalates = true,
  });

  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  bool isRestDay(DateTime date) =>
      restDays.contains(date.weekday) || restDates.contains(dateKey(date));
  bool get hasExerciseRestrictions =>
      exercisePosition != 'any' ||
      noEquipmentOnly ||
      lowMovementOnly ||
      avoidedAreas.isNotEmpty;

  ExperiencePreferences copyWith({
    double? textScale,
    bool? highContrast,
    String? exercisePosition,
    bool? noEquipmentOnly,
    bool? lowMovementOnly,
    List<String>? avoidedAreas,
    List<int>? restDays,
    List<String>? restDates,
    bool? companionEscalates,
  }) => ExperiencePreferences(
    textScale: textScale ?? this.textScale,
    highContrast: highContrast ?? this.highContrast,
    exercisePosition: exercisePosition ?? this.exercisePosition,
    noEquipmentOnly: noEquipmentOnly ?? this.noEquipmentOnly,
    lowMovementOnly: lowMovementOnly ?? this.lowMovementOnly,
    avoidedAreas: avoidedAreas ?? this.avoidedAreas,
    restDays: restDays ?? this.restDays,
    restDates: restDates ?? this.restDates,
    companionEscalates: companionEscalates ?? this.companionEscalates,
  );

  Map<String, dynamic> toMap() => {
    'textScale': textScale,
    'highContrast': highContrast,
    'exercisePosition': exercisePosition,
    'noEquipmentOnly': noEquipmentOnly,
    'lowMovementOnly': lowMovementOnly,
    'avoidedAreas': avoidedAreas,
    'restDays': restDays,
    'restDates': restDates,
    'companionEscalates': companionEscalates,
  };
  factory ExperiencePreferences.fromMap(dynamic value) {
    final map = value is Map ? value : const {};
    final scale = map['textScale'];
    final position = map['exercisePosition'];
    return ExperiencePreferences(
      textScale: scale is num && scale.isFinite
          ? scale.toDouble().clamp(1.0, 1.5)
          : 1,
      highContrast: map['highContrast'] == true,
      companionEscalates: map['companionEscalates'] != false,
      exercisePosition: ['any', 'seated', 'standing'].contains(position)
          ? position as String
          : 'any',
      noEquipmentOnly: map['noEquipmentOnly'] == true,
      lowMovementOnly: map['lowMovementOnly'] == true,
      avoidedAreas:
          (map['avoidedAreas'] is List ? map['avoidedAreas'] as List : const [])
              .whereType<String>()
              .where(bodyAreas.contains)
              .toSet()
              .toList(),
      restDays: (map['restDays'] is List ? map['restDays'] as List : const [])
          .whereType<int>()
          .where((day) => day >= 1 && day <= 7)
          .toSet()
          .toList(),
      restDates:
          (map['restDates'] is List ? map['restDates'] as List : const [])
              .whereType<String>()
              .where((key) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key))
              .toSet()
              .toList(),
    );
  }
  static const bodyAreas = [
    'eyes',
    'neck',
    'shoulders',
    'wrists',
    'back',
    'knees',
    'ankles',
  ];
}
