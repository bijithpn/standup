// Unit tests for PetConfigV2 and WindowInfo

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';

void main() {
  group('PetConfigV2.defaults()', () {
    test('returns non-null scale of 6.0', () {
      final d = PetConfigV2.defaults();
      expect(d.scale, equals(6.0));
    });

    test('returns non-empty themeId and petName', () {
      final d = PetConfigV2.defaults();
      expect(d.themeId, isNotEmpty);
      expect(d.petName, isNotEmpty);
    });

    test('returns freeRoam mode', () {
      final d = PetConfigV2.defaults();
      expect(d.mode, equals(PetMode.freeRoam));
    });

    test('pinnedDisplayId is null for defaults', () {
      final d = PetConfigV2.defaults();
      expect(d.pinnedDisplayId, isNull);
    });
  });

  group('PetConfigV2.fromJson()', () {
    test('empty map returns defaults for all fields', () {
      final c = PetConfigV2.fromJson({});
      final d = PetConfigV2.defaults();
      expect(c, equals(d));
    });

    test('unknown keys are ignored gracefully', () {
      final c = PetConfigV2.fromJson({
        'unknownKey': 'ignored',
        'anotherUnknown': 42,
        'themeId': 'test_theme',
      });
      expect(c.themeId, equals('test_theme'));
      expect(c.mode, equals(PetMode.freeRoam)); // defaults for missing fields
    });

    test('unknown mode value falls back to freeRoam', () {
      final c = PetConfigV2.fromJson({'mode': 'INVALID_MODE'});
      expect(c.mode, equals(PetMode.freeRoam));
    });

    test('partial JSON applies defaults for missing optional fields', () {
      final c = PetConfigV2.fromJson({
        'mode': 'singleDisplay',
        'pinnedDisplayId': 'display_1',
      });
      expect(c.mode, equals(PetMode.singleDisplay));
      expect(c.pinnedDisplayId, equals('display_1'));
      expect(c.scale, equals(6.0)); // defaulted
      expect(c.themeId, isNotEmpty); // defaulted
    });

    test('all valid fields roundtrip through fromJson(toJson())', () {
      final original = PetConfigV2(
        mode: PetMode.constrained,
        pinnedDisplayId: 'monitor_2',
        constraintWindowBounds: Rect.fromLTWH(50, 60, 350, 400),
        lastAnchorPoint: Offset(100, 200),
        themeId: 'orange_cat',
        petName: 'Felix',
        scale: 4.5,
      );
      final roundtripped = PetConfigV2.fromJson(original.toJson());
      expect(roundtripped, equals(original));
    });
  });

  group('PetConfigV2 round-trip serialization (Property 18)', () {
    // Exhaustive list of varied configs covering all field combinations.
    final testConfigs = <PetConfigV2>[
      PetConfigV2.defaults(),
      PetConfigV2(
        mode: PetMode.freeRoam,
        pinnedDisplayId: null,
        constraintWindowBounds: Rect.fromLTWH(0, 0, 200, 200),
        lastAnchorPoint: Offset(0, 0),
        themeId: 'grey_cat',
        petName: 'Mochi',
        scale: 6.0,
      ),
      PetConfigV2(
        mode: PetMode.constrained,
        pinnedDisplayId: null,
        constraintWindowBounds: Rect.fromLTWH(100, 100, 300, 300),
        lastAnchorPoint: Offset(150, 150),
        themeId: 'orange_cat',
        petName: 'Sunny',
        scale: 5.0,
      ),
      PetConfigV2(
        mode: PetMode.singleDisplay,
        pinnedDisplayId: 'display_abc_123',
        constraintWindowBounds: Rect.fromLTWH(0, 0, 800, 800),
        lastAnchorPoint: Offset(400, 400),
        themeId: 'black_cat',
        petName: 'Shadow',
        scale: 3.0,
      ),
      PetConfigV2(
        mode: PetMode.constrained,
        pinnedDisplayId: null,
        constraintWindowBounds: Rect.fromLTWH(10, 20, 200, 200),
        lastAnchorPoint: Offset(0, 0),
        themeId: 'corgi',
        petName: 'Biscuit',
        scale: 1.0,
      ),
    ];

    test('fromJson(toJson()) == original for all test configs', () {
      for (final config in testConfigs) {
        final json = config.toJson();
        final roundtripped = PetConfigV2.fromJson(json);
        expect(
          roundtripped,
          equals(config),
          reason: 'Round-trip failed for config: $config',
        );
      }
    });
  });

  group('WindowInfo', () {
    test('can be constructed with required fields only', () {
      const w = WindowInfo(
        windowId: 1,
        bounds: Rect.fromLTWH(0, 0, 800, 600),
        isMinimized: false,
        isVisible: true,
      );
      expect(w.windowId, equals(1));
      expect(w.appBundleId, isNull);
      expect(w.windowTitle, isNull);
    });

    test('equality holds for identical instances', () {
      const w1 = WindowInfo(
        windowId: 42,
        appBundleId: 'com.example.app',
        windowTitle: 'Test Window',
        bounds: Rect.fromLTWH(10, 20, 800, 600),
        isMinimized: false,
        isVisible: true,
      );
      const w2 = WindowInfo(
        windowId: 42,
        appBundleId: 'com.example.app',
        windowTitle: 'Test Window',
        bounds: Rect.fromLTWH(10, 20, 800, 600),
        isMinimized: false,
        isVisible: true,
      );
      expect(w1, equals(w2));
    });

    test('different windowIds are not equal', () {
      const w1 = WindowInfo(
        windowId: 1,
        bounds: Rect.fromLTWH(0, 0, 100, 100),
        isMinimized: false,
        isVisible: true,
      );
      const w2 = WindowInfo(
        windowId: 2,
        bounds: Rect.fromLTWH(0, 0, 100, 100),
        isMinimized: false,
        isVisible: true,
      );
      expect(w1, isNot(equals(w2)));
    });
  });
}
