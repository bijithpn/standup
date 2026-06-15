import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/settings_persistence.dart';

/// Creates a [SettingsPersistence] whose config file lives inside [dir].
SettingsPersistence _makePersistence(Directory dir) => SettingsPersistence(
  configPathOverride: '${dir.path}${Platform.pathSeparator}pet_config_v2.json',
);

void main() {
  late Directory tempDir;
  late File configFile;
  late File tmpFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('atomic_write_integration_');
    configFile = File(
      '${tempDir.path}${Platform.pathSeparator}pet_config_v2.json',
    );
    tmpFile = File(
      '${tempDir.path}${Platform.pathSeparator}pet_config_v2.json.tmp',
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Atomic write — Requirement 11.6', () {
    test('neither config nor .tmp file exists before first write', () {
      expect(
        configFile.existsSync(),
        isFalse,
        reason: 'Config file must not pre-exist in a fresh temp directory',
      );
      expect(
        tmpFile.existsSync(),
        isFalse,
        reason: '.tmp file must not pre-exist in a fresh temp directory',
      );
    });

    test(
      'config file exists and .tmp file is absent after flushPendingWrite',
      () async {
        final sp = _makePersistence(tempDir);
        sp.scheduleWrite(PetConfigV2.defaults());
        await sp.flushPendingWrite();

        expect(
          configFile.existsSync(),
          isTrue,
          reason: 'Config file must exist after a successful flush',
        );
        expect(
          tmpFile.existsSync(),
          isFalse,
          reason:
              '.tmp file must be renamed to the config file (no remnant allowed)',
        );
      },
    );

    test('config file contains correct JSON content after flush', () async {
      const config = PetConfigV2(
        mode: PetMode.constrained,
        pinnedDisplayId: 'monitor_1',
        constraintWindowBounds: Rect.fromLTWH(10, 20, 400, 350),
        lastAnchorPoint: Offset(150, 175),
        themeId: 'orange_cat',
        petName: 'Whiskers',
        scale: 6.5,
      );

      final sp = _makePersistence(tempDir);
      sp.scheduleWrite(config);
      await sp.flushPendingWrite();

      // Verify the file contains real JSON, not just an object instance dump.
      final raw = configFile.readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = PetConfigV2.fromJson(decoded);

      expect(
        loaded,
        equals(config),
        reason:
            'Round-trip JSON content must be identical to the scheduled config',
      );
    });

    test('no files created when flush is called with nothing pending', () async {
      final sp = _makePersistence(tempDir);
      await sp.flushPendingWrite(); // nothing scheduled

      expect(
        configFile.existsSync(),
        isFalse,
        reason: 'Config file must not be created if no write was scheduled',
      );
      expect(
        tmpFile.existsSync(),
        isFalse,
        reason: '.tmp file must not be created if no write was scheduled',
      );
    });

    test('successive flushes overwrite config file and leave no .tmp', () async {
      const configs = [
        PetConfigV2(
          mode: PetMode.freeRoam,
          pinnedDisplayId: null,
          constraintWindowBounds: Rect.fromLTWH(0, 0, 300, 300),
          lastAnchorPoint: Offset(50, 50),
          themeId: 'grey_cat',
          petName: 'Shadow',
          scale: 5.0,
        ),
        PetConfigV2(
          mode: PetMode.constrained,
          pinnedDisplayId: null,
          constraintWindowBounds: Rect.fromLTWH(50, 50, 250, 250),
          lastAnchorPoint: Offset(125, 125),
          themeId: 'orange_cat',
          petName: 'Mango',
          scale: 6.0,
        ),
      ];

      final sp = _makePersistence(tempDir);

      for (final config in configs) {
        sp.scheduleWrite(config);
        await sp.flushPendingWrite();

        expect(
          configFile.existsSync(),
          isTrue,
          reason: 'Config file must exist after every flush',
        );
        expect(
          tmpFile.existsSync(),
          isFalse,
          reason: '.tmp file must be absent after every flush',
        );

        // Verify the persisted content matches the most-recently written config.
        final raw = configFile.readAsStringSync();
        final loaded = PetConfigV2.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        expect(
          loaded,
          equals(config),
          reason:
              'Config file content must equal the last written config after successive writes',
        );
      }
    });

    test('loadSync on a second instance recovers config written atomically', () async {
      const original = PetConfigV2(
        mode: PetMode.freeRoam,
        pinnedDisplayId: null,
        constraintWindowBounds: Rect.fromLTWH(0, 0, 300, 300),
        lastAnchorPoint: Offset(400, 300),
        themeId: 'pixel_cat',
        petName: 'Pixel',
        scale: 7.0,
      );

      // Writer instance simulates a settings change at runtime.
      final writer = _makePersistence(tempDir);
      writer.scheduleWrite(original);
      await writer.flushPendingWrite();

      // Verify atomic write completed cleanly.
      expect(configFile.existsSync(), isTrue);
      expect(
        tmpFile.existsSync(),
        isFalse,
        reason: 'No .tmp remnant after atomic write',
      );

      // Reader instance simulates application restart.
      final reader = _makePersistence(tempDir);
      final loaded = reader.loadSync();

      expect(
        loaded,
        equals(original),
        reason:
            'A fresh SettingsPersistence must load the atomically-written config',
      );
    });

    test(
      'corrupt file recovery writes defaults atomically — no .tmp remnant',
      () async {
        // Seed a corrupt config file to exercise the recovery path.
        configFile.writeAsStringSync('}{invalid json{{');

        final sp = _makePersistence(tempDir);
        sp.loadSync(); // triggers scheduleWrite(defaults) internally

        // The dirty flag is now set; flush should overwrite with defaults.
        await sp.flushPendingWrite();

        expect(
          configFile.existsSync(),
          isTrue,
          reason: 'Config file must exist after recovery write',
        );
        expect(
          tmpFile.existsSync(),
          isFalse,
          reason: '.tmp must not remain after recovery atomic write',
        );

        // Content must now be valid defaults.
        final raw = configFile.readAsStringSync();
        final loaded = PetConfigV2.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        expect(
          loaded,
          equals(PetConfigV2.defaults()),
          reason:
              'Config file must contain defaults after corrupt-file recovery',
        );
      },
    );
  });
}
