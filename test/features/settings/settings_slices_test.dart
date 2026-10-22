import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_slices.dart';

void main() {
  group('SettingsModelSlices', () {
    test('companion slice reflects the parent model fields', () {
      const settings = SettingsModel(
        companionEnabled: true,
        companionPetName: 'Ginger',
        companionScale: 1.5,
        pipModeEnabled: true,
        pipOpacity: 0.8,
      );

      final companion = settings.companion;

      expect(companion.enabled, isTrue);
      expect(companion.petName, equals('Ginger'));
      expect(companion.scale, equals(1.5));
      expect(companion.pipModeEnabled, isTrue);
      expect(companion.pipOpacity, equals(0.8));
    });

    test('breakTiming slice reflects the parent model fields', () {
      const settings = SettingsModel(
        shortBreakIntervalMinutes: 25,
        shortBreakDurationSeconds: 30,
        longBreakIntervalMinutes: 90,
        dailyBreakGoalCount: 8,
      );

      final timing = settings.breakTiming;

      expect(timing.shortBreakIntervalMinutes, equals(25));
      expect(timing.shortBreakDurationSeconds, equals(30));
      expect(timing.longBreakIntervalMinutes, equals(90));
      expect(timing.dailyBreakGoalCount, equals(8));
    });

    test('appearance slice reflects the parent model fields', () {
      const settings = SettingsModel(
        breakTheme: 'dark',
        breakTemplate: 'zen_mode',
        clockFaceStyle: 'digital',
        trayIconStyle: 'minimal',
      );

      final appearance = settings.appearance;

      expect(appearance.breakTheme, equals('dark'));
      expect(appearance.breakTemplate, equals('zen_mode'));
      expect(appearance.clockFaceStyle, equals('digital'));
      expect(appearance.trayIconStyle, equals('minimal'));
    });

    test('slices stay in sync after copyWith produces a new model', () {
      const original = SettingsModel(companionPetName: 'Ginger');
      final updated = original.copyWith(companionPetName: 'Biscuit');

      expect(original.companion.petName, equals('Ginger'));
      expect(updated.companion.petName, equals('Biscuit'));
    });
  });

  group(
    'slice value equality (required for Selector-based rebuild scoping)',
    () {
      test(
        'two companion slices from equal fields are ==, with equal hashCodes',
        () {
          const a = SettingsModel(
            companionPetName: 'Ginger',
            companionScale: 1.2,
          );
          const b = SettingsModel(
            companionPetName: 'Ginger',
            companionScale: 1.2,
          );

          // Distinct SettingsModel instances, distinct slice instances (no
          // caching) — equality must come from field values, not identity.
          expect(identical(a.companion, b.companion), isFalse);
          expect(a.companion, equals(b.companion));
          expect(a.companion.hashCode, equals(b.companion.hashCode));
        },
      );

      test(
        'companion slices differ when an unrelated companion field differs',
        () {
          const a = SettingsModel(companionPetName: 'Ginger');
          const b = SettingsModel(companionPetName: 'Biscuit');

          expect(a.companion, isNot(equals(b.companion)));
        },
      );

      test('companion slice equality ignores fields outside the slice', () {
        // Two models differing only in a breakTiming field must still
        // produce an equal companion slice — that's the entire point of
        // scoping: an unrelated change shouldn't register as a difference.
        const a = SettingsModel(shortBreakIntervalMinutes: 20);
        const b = SettingsModel(shortBreakIntervalMinutes: 45);

        expect(a.companion, equals(b.companion));
      });

      test('breakTiming slice equality holds and detects real differences', () {
        const a = SettingsModel(shortBreakIntervalMinutes: 20);
        const b = SettingsModel(shortBreakIntervalMinutes: 20);
        const c = SettingsModel(shortBreakIntervalMinutes: 45);

        expect(a.breakTiming, equals(b.breakTiming));
        expect(a.breakTiming, isNot(equals(c.breakTiming)));
      });

      test('appearance slice equality holds and detects real differences', () {
        const a = SettingsModel(breakTheme: 'dark');
        const b = SettingsModel(breakTheme: 'dark');
        const c = SettingsModel(breakTheme: 'light');

        expect(a.appearance, equals(b.appearance));
        expect(a.appearance, isNot(equals(c.appearance)));
      });

      test(
        'companion slice equality accounts for the unlockedPets list contents',
        () {
          const a = SettingsModel(unlockedPets: ['orange_cat']);
          const b = SettingsModel(unlockedPets: ['orange_cat']);
          const c = SettingsModel(unlockedPets: ['orange_cat', 'panda']);

          expect(a.companion, equals(b.companion));
          expect(a.companion, isNot(equals(c.companion)));
        },
      );
    },
  );
}
