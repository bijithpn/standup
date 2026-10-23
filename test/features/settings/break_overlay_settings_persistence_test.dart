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

FakeStorageService _storage() {
  final box = _MockSettingsBox();
  when(() => box.put(any())).thenReturn(1);
  when(() => box.get(any())).thenReturn(null);
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
