import 'dart:math';

/// Short, varied wording for each health reminder so repeats don't read as
/// the same message. Plain tips only — no medical claims.
class HealthReminderCopy {
  const HealthReminderCopy._();

  static const Map<String, List<String>> _variants = {
    'eyeblink': [
      'Rest your eyes — look 20 feet away for 20 seconds',
      'Blink a few times and look into the distance',
      'Look away from the screen for a moment',
    ],
    'posture': [
      'Sit tall and relax your shoulders',
      'Posture check — feet flat, back supported',
      'Unclench your jaw and drop your shoulders',
    ],
    'hydration': [
      'Time for a glass of water',
      'Grab a drink of water',
      'Stay hydrated — sip some water',
    ],
    'stretch': [
      'Roll your shoulders and stretch your neck',
      'Stretch your wrists and fingers',
      'Reach overhead and stretch your back',
    ],
    'standup': [
      'Stand up and walk around for a minute',
      'Time to move — stand up and shake it out',
      'Take a short walk, even to the window',
    ],
  };

  static bool isKnown(String? type) => _variants.containsKey(type);

  /// One random line for [type]; falls back to the eye-rest wording.
  static String text(String? type, [Random? random]) {
    final list = _variants[type] ?? _variants['eyeblink']!;
    return list[(random ?? Random()).nextInt(list.length)];
  }

  /// Short label for the compact pill.
  static String pill(String? type) => switch (type) {
    'posture' => 'Posture check',
    'hydration' => 'Drink some water',
    'stretch' => 'Time to stretch',
    'standup' => 'Stand up & move',
    _ => 'Rest your eyes',
  };

  /// Big wording for the full-screen poster.
  static String poster(String? type) => switch (type) {
    'posture' => 'Watch your posture!',
    'hydration' => 'Drink some water!',
    'stretch' => 'Time to stretch!',
    'standup' => 'Stand up and move!',
    _ => 'Rest your eyes!',
  };
}
