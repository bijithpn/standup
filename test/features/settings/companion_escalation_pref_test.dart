import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/settings/experience_preferences.dart';

void main() {
  test('companion escalation defaults on and survives a round trip', () {
    expect(ExperiencePreferences.fromMap(null).companionEscalates, isTrue);
    final off = const ExperiencePreferences().copyWith(
      companionEscalates: false,
    );
    expect(
      ExperiencePreferences.fromMap(off.toMap()).companionEscalates,
      isFalse,
    );
  });
}
