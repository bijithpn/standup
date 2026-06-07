// Unit and property tests for SettingsPersistence
// Tasks 6.2 and 6.3 — Requirements 11.2, 11.4, 11.5, 11.6, 11.7

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/settings_persistence.dart';

SettingsPersistence _make(Directory dir) => SettingsPersistence(
  configPathOverride: '${dir.path}${Platform.pathSeparator}pet_config_v2.json',
);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('settings_persistence_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('SettingsPersistence.loadSync()', () {
    test('returns defaults when config file does not exist', () {
      final sp = _make(tempDir);
      final config = sp.loadSync();
      expect(config, equals(PetConfigV2.defaults()));
    });

    test('returns defaults and schedules write on corrupt JSON', () {
      final configFile = File(
        '${tempDir.path}${Platform.pathSeparator}pet_config_v2.json',
      );
      configFile.writeAsStringSync('not valid json }{{{');

      final sp = _make(tempDir);
      final config = sp.loadSync();

      // Should fall back to defaults
      expect(config, equals(PetConfigV2.defaults()));

      // dirty flag should be set — flushing should write defaults to disk
      sp.flushPendingWrite();
      expect(configFile.existsSync(), isTrue);
    });

    test('loads a previously written config correctly', () {
      const original = PetConfigV2(
        mode: PetMode.constrained,
        pinnedDisplayId: null,
        constraintWindowBounds: Rect.fromLTWH(50, 60, 300, 300),
        lastAnchorPoint: Offset(100, 200),
        themeId: 'orange_cat',
        petName: 'Cleo',
        scale: 5.5,
      );

      final sp = _make(tempDir);
      sp.scheduleWrite(original);
      sp.flushPendingWrite();

      final sp2 = _make(tempDir);
      final loaded = sp2.loadSync();
      expect(loaded, equals(original));
    });
  });

  group('SettingsPersistence atomic write (Property 18 I/O path)', () {
    final testConfigs = <PetConfigV2>[
      PetConfigV2.defaults(),
      PetConfigV2(
        mode: PetMode.constrained,
        pinnedDisplayId: null,
        constraintWindowBounds: Rect.fromLTWH(200, 100, 300, 250),
        lastAnchorPoint: Offset(350, 225),
        themeId: 'grey_cat',
        petName: 'Mochi',
        scale: 6.0,
      ),
    ];

    test(
      'scheduleWrite → flushPendingWrite → loadSync roundtrip for all configs',
      () {
        for (final config in testConfigs) {
          final sp = _make(tempDir);
          sp.scheduleWrite(config);
          sp.flushPendingWrite();

          final sp2 = _make(tempDir);
          final loaded = sp2.loadSync();
          expect(
            loaded,
            equals(config),
            reason: 'Round-trip I/O failed for config: $config',
          );
        }
      },
    );

    test('.tmp file is cleaned up after atomic write (renamed to target)', () {
      const config = PetConfigV2(
        mode: PetMode.freeRoam,
        pinnedDisplayId: null,
        constraintWindowBounds: Rect.fromLTWH(100, 100, 300, 300),
        lastAnchorPoint: Offset.zero,
        themeId: 'grey_cat',
        petName: 'TestPet',
        scale: 6.0,
      );

      final sp = _make(tempDir);
      sp.scheduleWrite(config);
      sp.flushPendingWrite();

      final configFile = File(
        '${tempDir.path}${Platform.pathSeparator}pet_config_v2.json',
      );
      final tmpFile = File(
        '${tempDir.path}${Platform.pathSeparator}pet_config_v2.json.tmp',
      );

      expect(
        configFile.existsSync(),
        isTrue,
        reason: 'Config file should exist after flush',
      );
      expect(
        tmpFile.existsSync(),
        isFalse,
        reason: '.tmp file should be cleaned up (renamed) after flush',
      );
    });

    test('flushPendingWrite is a no-op when nothing is dirty', () {
      final sp = _make(tempDir);
      sp.flushPendingWrite(); // no-op
      final configFile = File(
        '${tempDir.path}${Platform.pathSeparator}pet_config_v2.json',
      );
      expect(configFile.existsSync(), isFalse);
    });
  });

  group('SettingsPersistence error handling (Req 11.7)', () {
    test('write to bad path does not crash — engine continues normally', () {
      // Use a deeply nested non-existent path with no parent dirs.
      final badPath =
          '${tempDir.path}${Platform.pathSeparator}deep${Platform.pathSeparator}nested${Platform.pathSeparator}missing${Platform.pathSeparator}pet_config_v2.json';
      final sp = SettingsPersistence(configPathOverride: badPath);
      sp.scheduleWrite(PetConfigV2.defaults());

      // Must NOT throw regardless of I/O failure.
      expect(() => sp.flushPendingWrite(), returnsNormally);
    });
  });
}
