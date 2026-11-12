import 'dart:io';

import 'package:breakmate/core/services/health_reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every reminder type has its own, distinct sound file', () {
    final names = [
      for (final k in HealthReminderKind.values) k.typeName,
      'custom',
    ];
    final bytes = {
      for (final n in names)
        n: File('assets/audio/reminder_$n.wav').readAsBytesSync(),
    };
    final unique = bytes.values
        .map(
          (b) =>
              b.length * 31 +
              b.fold<int>(0, (a, x) => (a * 33 + x) & 0xFFFFFFF),
        )
        .toSet();
    expect(unique.length, names.length);
  });
}
