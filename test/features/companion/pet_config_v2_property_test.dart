// Property 18: Settings serialization round-trip
// Task 1.2 — Validates: Requirements 11.4, 11.5

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';

void main() {
  // Exhaustive list of varied PetConfigV2 instances covering all field
  // combinations and edge cases for the round-trip serialization property.
  final testConfigs = <PetConfigV2>[
    PetConfigV2.defaults(),
    PetConfigV2(
      mode: PetMode.freeRoam,
      pinnedDisplayId: null,
      constraintWindowBounds: Rect.fromLTWH(0, 0, 200, 200),
      lastAnchorPoint: Offset.zero,
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
      lastAnchorPoint: Offset.zero,
      themeId: 'corgi',
      petName: 'Biscuit',
      scale: 1.0,
    ),
    PetConfigV2(
      mode: PetMode.singleDisplay,
      pinnedDisplayId: 'monitor_primary',
      constraintWindowBounds: Rect.fromLTWH(0, 0, 300, 300),
      lastAnchorPoint: Offset(960, 540),
      themeId: 'husky',
      petName: 'Storm',
      scale: 4.5,
    ),
    PetConfigV2(
      mode: PetMode.freeRoam,
      pinnedDisplayId: null,
      constraintWindowBounds: Rect.fromLTWH(100.5, 200.75, 350.25, 400.5),
      lastAnchorPoint: Offset(0.1, 0.9),
      themeId: 'cat_1',
      petName: 'Tiny',
      scale: 10.0,
    ),
    PetConfigV2(
      mode: PetMode.freeRoam,
      pinnedDisplayId: null,
      constraintWindowBounds: Rect.fromLTWH(0, 0, 300, 300),
      lastAnchorPoint: Offset(-100, -50),
      themeId: 'dalmatian',
      petName: 'Spot',
      scale: 7.5,
    ),
  ];

  group('Property 18: PetConfigV2 round-trip serialization', () {
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

    test('toJson() produces non-null values for all required fields', () {
      for (final config in testConfigs) {
        final json = config.toJson();
        expect(json['mode'], isNotNull);
        expect(json['constraintWindowBounds'], isNotNull);
        expect(json['lastAnchorPoint'], isNotNull);
        expect(json['themeId'], isNotNull);
        expect(json['petName'], isNotNull);
        expect(json['scale'], isNotNull);
      }
    });

    test('fromJson handles extra/unknown keys without throwing', () {
      for (final config in testConfigs) {
        final json = config.toJson();
        json['extraKey'] = 'ignoredValue';
        json['anotherExtra'] = 42;
        expect(
          () => PetConfigV2.fromJson(json),
          returnsNormally,
          reason: 'fromJson should ignore unknown keys for config: $config',
        );
      }
    });
  });
}
