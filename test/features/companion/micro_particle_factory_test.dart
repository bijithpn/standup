// Property tests for MicroParticleFactory QuietMode suppression.
//
//
// Property 10: QuietMode suppresses all particle spawns.
//
//   - Each factory method returns non-null with quietMode=false
//   - Each factory method returns null with quietMode=true

// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide test, group, expect;

import 'package:breakmate/features/companion/flame/micro_particle_factory.dart';

// Helper to enumerate all factory methods under test.
typedef _FactoryMethod = dynamic Function(Offset center, {bool quietMode});

final List<(String, _FactoryMethod)> _factories = [
  ('heart', MicroParticleFactory.heart),
  ('crumbs', MicroParticleFactory.crumbs),
  ('sparkle', MicroParticleFactory.sparkle),
  ('sleepBubble', MicroParticleFactory.sleepBubble),
  ('bounce', MicroParticleFactory.bounce),
];

void main() {
  // ── Property 10: QuietMode suppresses all particle spawns ─────────────────
  group('Property 10: QuietMode suppresses all particle spawns (Task 2.2)', () {
    // Feature: desktop-companion-interaction, Property 10: QuietMode suppresses all particle spawns

    for (final (name, factory) in _factories) {
      test('$name returns null when quietMode=true', () {
        const center = Offset(100, 200);
        final result = factory(center, quietMode: true);
        expect(
          result,
          isNull,
          reason: '$name should return null when quietMode=true',
        );
      });

      test('$name returns non-null when quietMode=false', () {
        const center = Offset(100, 200);
        final result = factory(center, quietMode: false);
        expect(
          result,
          isNotNull,
          reason: '$name should return non-null when quietMode=false',
        );
      });

      test('$name returns non-null with default quietMode', () {
        const center = Offset(100, 200);
        final result = factory(center);
        expect(
          result,
          isNotNull,
          reason: '$name default should return non-null',
        );
      });
    }

    // Glados property: for any Offset and any trigger, quietMode=true → null
    Glados2(
      any.doubleInRange(-10000.0, 10000.0),
      any.doubleInRange(-10000.0, 10000.0),
    ).test(
      'all factory methods return null for any center when quietMode=true',
      (x, y) {
        final center = Offset(x, y);
        for (final (name, factory) in _factories) {
          final result = factory(center, quietMode: true);
          expect(
            result,
            isNull,
            reason: '$name($x, $y) with quietMode=true should be null',
          );
        }
      },
    );

    Glados2(
      any.doubleInRange(0.0, 2000.0),
      any.doubleInRange(0.0, 2000.0),
    ).test(
      'all factory methods return non-null for valid centers when quietMode=false',
      (x, y) {
        final center = Offset(x, y);
        for (final (name, factory) in _factories) {
          final result = factory(center, quietMode: false);
          expect(
            result,
            isNotNull,
            reason: '$name($x, $y) with quietMode=false should be non-null',
          );
        }
      },
    );
  });

  // ── Unit tests for individual particle specs ────────────────────────────────
  group('MicroParticleFactory particle specifications', () {
    const center = Offset(200.0, 300.0);

    test('heart: position matches center', () {
      final comp = MicroParticleFactory.heart(center);
      expect(comp, isNotNull);
      expect(comp!.position.x, equals(center.dx));
      expect(comp.position.y, equals(center.dy));
    });

    test('crumbs: position matches center', () {
      final comp = MicroParticleFactory.crumbs(center);
      expect(comp, isNotNull);
      expect(comp!.position.x, equals(center.dx));
      expect(comp.position.y, equals(center.dy));
    });

    test('sparkle: position matches center', () {
      final comp = MicroParticleFactory.sparkle(center);
      expect(comp, isNotNull);
      expect(comp!.position.x, equals(center.dx));
      expect(comp.position.y, equals(center.dy));
    });

    test('sleepBubble: position matches center', () {
      final comp = MicroParticleFactory.sleepBubble(center);
      expect(comp, isNotNull);
      expect(comp!.position.x, equals(center.dx));
      expect(comp.position.y, equals(center.dy));
    });

    test('bounce: position matches center', () {
      final comp = MicroParticleFactory.bounce(center);
      expect(comp, isNotNull);
      expect(comp!.position.x, equals(center.dx));
      expect(comp.position.y, equals(center.dy));
    });

    // Verify all five methods are distinct (not the same particle)
    test('all five factory methods produce independent components', () {
      final results = [
        MicroParticleFactory.heart(center),
        MicroParticleFactory.crumbs(center),
        MicroParticleFactory.sparkle(center),
        MicroParticleFactory.sleepBubble(center),
        MicroParticleFactory.bounce(center),
      ];
      expect(results.every((c) => c != null), isTrue);
      // All are different instances
      for (var i = 0; i < results.length; i++) {
        for (var j = i + 1; j < results.length; j++) {
          expect(
            identical(results[i], results[j]),
            isFalse,
            reason: 'factory $i and $j returned the same instance',
          );
        }
      }
    });
  });
}
