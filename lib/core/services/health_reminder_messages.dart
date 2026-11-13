import 'dart:math';

/// Reminder wording per reminder type, with random variants; `custom:` prefixed types carry the user's own title.
class HealthReminderMessages {
  const HealthReminderMessages._();

  static const Map<String, List<String>> _variants = {
    'eyeblink': [
      'Look at something far away for 20 seconds.',
      'Give your eyes a rest. Look out the window.',
      'Look away from the screen for a bit.',
    ],
    'blink': [
      'Blink a few times. Your eyes are probably dry.',
      'You\'ve been staring. Blink slowly, ten times.',
      'Move back a bit. Screen should be an arm away.',
    ],
    'posture': [
      'Sit up and drop your shoulders.',
      'Feet flat, back against the chair.',
      'Unclench your jaw.',
    ],
    'hydration': [
      'Go get some water.',
      'Have a glass of water.',
      'Water break.',
    ],
    'stretch': [
      'Roll your shoulders and stretch your neck.',
      'Shake out your wrists and fingers.',
      'Reach up and stretch your back.',
    ],
    'standup': [
      'Get up and walk around for a minute.',
      'Stand up and move a little.',
      'Walk to the window and back.',
    ],
  };

  static const customPrefix = 'custom:';

  static bool isCustom(String? type) => type?.startsWith(customPrefix) ?? false;

  static String _customTitle(String type) =>
      type.substring(customPrefix.length);

  static bool isKnown(String? type) =>
      _variants.containsKey(type) || isCustom(type);

  static String text(String? type, [Random? random]) {
    if (isCustom(type)) return _customTitle(type!);
    final list = _variants[type] ?? _variants['eyeblink']!;
    return list[(random ?? Random()).nextInt(list.length)];
  }

  // Short labels for the compact pill display.
  static const Map<String, List<String>> _pills = {
    'eyeblink': ['Rest your eyes', 'Look away for a bit', 'Look far away'],
    'blink': ['Blink more', 'Blink a few times', 'Move back from the screen'],
    'posture': ['Sit up', 'Check your posture', 'Drop your shoulders'],
    'hydration': ['Drink some water', 'Water break', 'Have some water'],
    'stretch': ['Stretch', 'Roll your shoulders', 'Shake out your wrists'],
    'standup': ['Stand up', 'Take a short walk', 'Move around'],
  };

  static String pill(String? type, [Random? random]) {
    if (isCustom(type)) return _customTitle(type!);
    final list = _pills[type] ?? _pills['eyeblink']!;
    return list[(random ?? Random()).nextInt(list.length)];
  }

  /// Stable headings for reminder cards; custom content stays in the body.
  static String heading(String? type) => isCustom(type)
      ? 'Your reminder'
      : isKnown(type)
      ? poster(type)
      : 'A moment for you';

  // Single fixed title for the poster display.
  static String poster(String? type) => isCustom(type)
      ? _customTitle(type!)
      : switch (type) {
          'blink' => 'Blink',
          'posture' => 'Sit up',
          'hydration' => 'Drink some water',
          'stretch' => 'Stretch',
          'standup' => 'Stand up',
          _ => 'Rest your eyes',
        };
}
