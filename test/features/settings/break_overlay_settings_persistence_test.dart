import 'package:breakmate/features/settings/experience_preferences.dart';
import 'package:breakmate/features/settings/work_schedule.dart';
import 'package:breakmate/features/settings/notification_intensity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:objectbox/objectbox.dart';

import 'package:breakmate/core/storage/models/companion_preferences.dart';
import 'package:breakmate/core/storage/models/settings_snapshot.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

import '../../core/services/timer_engine_drift_test.dart'
    show FakeStorageService;

class _MockSettingsBox extends Mock implements Box<SettingsSnapshot> {}

class _MockCompanionBox extends Mock implements Box<CompanionPreferences> {}

FakeStorageService _storage({bool readSnapshot = false}) {
  SettingsSnapshot? snapshot;
  final box = _MockSettingsBox();
  when(() => box.put(any())).thenAnswer((invocation) {
    snapshot = invocation.positionalArguments.single as SettingsSnapshot;
    return 1;
  });
  when(() => box.get(any())).thenAnswer((_) => readSnapshot ? snapshot : null);
  final companion = _MockCompanionBox();
  when(() => companion.put(any())).thenReturn(1);
  when(() => companion.get(any())).thenReturn(null);
  return FakeStorageService()
    ..settingsBox = box
    ..companionPreferencesBox = companion;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSnapshot());
    registerFallbackValue(_FakeCompanionPrefs());
  });

  for (final readSnapshot in [false, true]) {
    test(
      'weekly shifts and intensity survive restart (snapshot: $readSnapshot)',
      () async {
        final storage = _storage(readSnapshot: readSnapshot);
        final first = SettingsRepository(storage: storage);
        await first.save(
          NotificationIntensity.gentle.apply(
            first.currentSettings.copyWith(
              workingHoursEnabled: true,
              workingDays: [5],
              weeklySchedule: {
                5: const WorkSchedule(
                  start: '22:00',
                  end: '06:00',
                  lunchStart: '01:00',
                  lunchEnd: '01:30',
                ),
              },
            ),
          ),
        );
        final restored = SettingsRepository(storage: storage);
        await restored.load();
        expect(restored.currentSettings.workingHoursEnabled, isTrue);
        expect(restored.currentSettings.workingDays, [5]);
        expect(restored.currentSettings.weeklySchedule[5]!.end, '06:00');
        expect(restored.currentSettings.weeklySchedule[5]!.lunchEnd, '01:30');
        expect(
          NotificationIntensity.gentle.matches(restored.currentSettings),
          isTrue,
        );
      },
    );
  }

  for (final readSnapshot in [false, true]) {
    test(
      'experience preferences survive restart (snapshot: $readSnapshot)',
      () async {
        final storage = _storage(readSnapshot: readSnapshot);
        final first = SettingsRepository(storage: storage);
        await first.save(
          first.currentSettings.copyWith(
            experience: const ExperiencePreferences(
              textScale: 1.5,
              highContrast: true,
              exercisePosition: 'seated',
              avoidedAreas: ['neck'],
              restDays: [7],
              restDates: ['2026-11-16'],
            ),
          ),
        );
        final restored = SettingsRepository(storage: storage);
        await restored.load();
        expect(
          restored.currentSettings.experience.toMap(),
          first.currentSettings.experience.toMap(),
        );
      },
    );
  }

  test('theme mode, breathing pattern, chime and prompt persist', () async {
    final storage = _storage();
    final first = SettingsRepository(storage: storage);
    await first.load();
    await first.save(
      first.currentSettings.copyWith(
        overlayThemeMode: 'system',
        breathPreset: 'relax',
        breakChimeEnabled: true,
        lookedAwayPromptEnabled: true,
      ),
    );

    final second = SettingsRepository(storage: storage);
    await second.load();
    final s = second.currentSettings;
    expect(s.overlayThemeMode, 'system');
    expect(s.breathPreset, 'relax');
    expect(s.breakChimeEnabled, isTrue);
    expect(s.lookedAwayPromptEnabled, isTrue);
  });

  for (final readSnapshot in [false, true]) {
    test(
      'mouse dismissal persists on and off (snapshot: $readSnapshot)',
      () async {
        final storage = _storage(readSnapshot: readSnapshot);
        final first = SettingsRepository(storage: storage);
        await first.save(
          first.currentSettings.copyWith(dismissReminderOnMouseMove: true),
        );
        final second = SettingsRepository(storage: storage);
        await second.load();
        expect(second.currentSettings.dismissReminderOnMouseMove, isTrue);
        await second.save(
          second.currentSettings.copyWith(dismissReminderOnMouseMove: false),
        );
        final third = SettingsRepository(storage: storage);
        await third.load();
        expect(third.currentSettings.dismissReminderOnMouseMove, isFalse);
      },
    );
  }

  test('a fresh install keeps the old look and stays quiet', () async {
    final repo = SettingsRepository(storage: _storage());
    await repo.load();
    final s = repo.currentSettings;
    expect(s.overlayThemeMode, 'dark');
    expect(s.breathPreset, 'box');
    expect(s.breakChimeEnabled, isFalse);
    expect(s.lookedAwayPromptEnabled, isFalse);
  });
}

class _FakeSnapshot extends Fake implements SettingsSnapshot {}

class _FakeCompanionPrefs extends Fake implements CompanionPreferences {}
