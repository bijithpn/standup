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

  static const Map<String, List<String>> _pills = {
    'eyeblink': ['Rest your eyes', 'Look away for a moment', 'Blink & refocus'],
    'posture': ['Posture check', 'Sit tall', 'Relax your shoulders'],
    'hydration': ['Drink some water', 'Time for water', 'Stay hydrated'],
    'stretch': [
      'Time to stretch',
      'Roll your shoulders',
      'Stretch your wrists',
    ],
    'standup': ['Stand up & move', 'Take a short walk', 'Time to move'],
  };

  /// Short label for the compact pill (one of a few variants).
  static String pill(String? type, [Random? random]) {
    final list = _pills[type] ?? _pills['eyeblink']!;
    return list[(random ?? Random()).nextInt(list.length)];
  }

  /// Big wording for the full-screen poster.
  static String poster(String? type) => switch (type) {
    'posture' => 'Watch your posture!',
    'hydration' => 'Drink some water!',
    'stretch' => 'Time to stretch!',
    'standup' => 'Stand up and move!',
    _ => 'Rest your eyes!',
  };
}
