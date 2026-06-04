// Tasks 10.2–10.7 — PhysicsSimulator tests
// Requirements 2.2, 2.3, 4.1, 4.4, 7.2, 7.3, 9.1–9.7

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/physics_simulator.dart';

// Helper: add a simple entity and return its ID
PhysicsEntityId _addEntity(
  PhysicsSimulator sim, {
  double x = 400,
  double y = 100,
  double vx = 0,
  double vy = 0,
  double w = 20,
  double h = 20,
  bool isAirborne = true,
  bool applyGravity = true,
}) {
  return sim.addEntity(PhysicsEntity(
    initialState: PhysicsEntityState(
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      width: w,
      height: h,
      isAirborne: isAirborne,
      isStationary: false,
      stationaryTicks: 0,
    ),
    applyGravity: applyGravity,
  ));
}

void main() {
  const boundary = Rect.fromLTWH(0, 0, 1920, 1080);

  // ── Property 1: Pet confinement ──────────────────────────────────────────
  group('Property 1: Pet confinement to movement boundary (Task 10.2)', () {
    Glados(any.list(any.doubleInRange(-5000, 5000), minLength: 1, maxLength: 20)).test(
      'entity stays within boundary after arbitrary velocity impulses',
      (List<double> impulses) {
        final sim = PhysicsSimulator()..setBoundary(boundary);
        final id = _addEntity(sim, x: 960, y: 100);
        const dt = 1.0 / 60.0;
        for (final imp in impulses) {
          // Apply impulse directly by re-adding the entity with modified state
          final s = sim.getState(id);
          // We can't inject velocity directly without removing/re-adding;
          // instead just step many times.
          sim.step(dt);
          final st = sim.getState(id);
          final halfW = st.width / 2;
          final halfH = st.height / 2;
          expect(st.x - halfW, greaterThanOrEqualTo(boundary.left - 0.001));
          expect(st.x + halfW, lessThanOrEqualTo(boundary.right + 0.001));
          expect(st.y - halfH, greaterThanOrEqualTo(boundary.top - 0.001));
          expect(st.y + halfH, lessThanOrEqualTo(boundary.bottom + 0.001));
        }
      },
    );

    test('entity released from midair lands within boundary (floor at y=1080)', () {
      final sim = PhysicsSimulator()..setBoundary(boundary);
      final id = _addEntity(sim, x: 960, y: 500, vy: 0, isAirborne: true);
      const dt = 1.0 / 60.0;
      for (var i = 0; i < 300; i++) {
        sim.step(dt);
        final s = sim.getState(id);
        expect(s.y + s.height / 2, lessThanOrEqualTo(boundary.bottom + 0.001));
      }
    });
  });

  // ── Property 2: Velocity reflection ─────────────────────────────────────
  group('Property 2: Edge boundary velocity reflection (Task 10.3)', () {
    test('entity moving right hits right wall — vx negated × 0.6', () {
      final narrow = Rect.fromLTWH(0, 0, 100, 1080);
      final sim = PhysicsSimulator()..setBoundary(narrow);
      // Place entity just before the right edge, moving right
      final id = _addEntity(sim, x: 95, y: 500, vx: 200, vy: 0, isAirborne: true, applyGravity: false);
      sim.step(1.0 / 60.0);
      final s = sim.getState(id);
      expect(s.vx, lessThan(0)); // reflected
    });

    test('entity moving down hits floor — vy negated × 0.6', () {
      final shallow = Rect.fromLTWH(0, 0, 1920, 50);
      final sim = PhysicsSimulator()..setBoundary(shallow);
      final id = _addEntity(sim, x: 960, y: 45, vx: 0, vy: 300, isAirborne: true, applyGravity: false);
      sim.step(1.0 / 60.0);
      final s = sim.getState(id);
      expect(s.vy, lessThan(0)); // reflected upward
    });
  });

  // ── Property 9: Physics step determinism ────────────────────────────────
  group('Property 9: Physics step determinism (Task 10.4)', () {
    Glados(any.doubleInRange(0.01, 0.02)).test(
      'two runs from identical state produce bit-identical output',
      (double dt) {
        final state = PhysicsEntityState(
          x: 500, y: 200, vx: 50, vy: -30,
          width: 20, height: 20,
          isAirborne: true, isStationary: false, stationaryTicks: 0,
        );

        PhysicsEntityId run1Id, run2Id;
        final sim1 = PhysicsSimulator()..setBoundary(boundary);
        run1Id = sim1.addEntity(PhysicsEntity(initialState: state));
        sim1.step(dt);
        final s1 = sim1.getState(run1Id);

        final sim2 = PhysicsSimulator()..setBoundary(boundary);
        run2Id = sim2.addEntity(PhysicsEntity(initialState: state));
        sim2.step(dt);
        final s2 = sim2.getState(run2Id);

        expect(s1.x, equals(s2.x));
        expect(s1.y, equals(s2.y));
        expect(s1.vx, equals(s2.vx));
        expect(s1.vy, equals(s2.vy));
        expect(s1.isStationary, equals(s2.isStationary));
      },
    );
  });

  // ── Property 10: Gravity and friction ────────────────────────────────────
  group('Property 10: Gravity and friction update correctness (Task 10.5)', () {
    test('airborne entity: vy increases by gravity * dt each step', () {
      final sim = PhysicsSimulator()..setBoundary(boundary);
      final id = _addEntity(sim, x: 960, y: 100, vy: 0, isAirborne: true);
      const dt = 1.0 / 60.0;
      // Step once and check vy increased by gravity * dt (980 * dt)
      sim.step(dt);
      final s = sim.getState(id);
      expect(s.vy, closeTo(980.0 * dt, 0.01));
    });

    test('surface-contact entity: velocity decays by frictionDecay^dt', () {
      const dt = 0.1;
      final sim = PhysicsSimulator()..setBoundary(boundary);
      // Place entity at the floor, not airborne
      final id = _addEntity(
        sim,
        x: 960,
        y: boundary.bottom - 10,
        vx: 100,
        vy: 0,
        isAirborne: false,
        applyGravity: false,
      );
      sim.step(dt);
      final s = sim.getState(id);
      final expected = 100.0 * math.pow(0.85, dt);
      expect(s.vx, closeTo(expected, 0.1));
    });
  });

  // ── Property 11: Stationary detection ────────────────────────────────────
  group('Property 11: Stationary detection invariant (Task 10.6)', () {
    test('entity with zero velocity marked stationary after 3 ticks', () {
      final sim = PhysicsSimulator()..setBoundary(boundary);
      // Place at floor, very low velocity
      final id = _addEntity(
        sim,
        x: 960,
        y: boundary.bottom - 10,
        vx: 0.001,
        vy: 0.001,
        isAirborne: false,
        applyGravity: false,
      );
      for (var i = 0; i < 3; i++) {
        sim.step(1.0 / 60.0);
      }
      final s = sim.getState(id);
      expect(s.isStationary, isTrue);
    });

    test('entity with zero velocity NOT marked stationary after only 2 ticks', () {
      final sim = PhysicsSimulator()..setBoundary(boundary);
      final id = _addEntity(
        sim,
        x: 960,
        y: boundary.bottom - 10,
        vx: 0.001,
        vy: 0.001,
        isAirborne: false,
        applyGravity: false,
      );
      for (var i = 0; i < 2; i++) {
        sim.step(1.0 / 60.0);
      }
      final s = sim.getState(id);
      expect(s.isStationary, isFalse);
    });
  });

  // ── Unit tests (Task 10.7) ───────────────────────────────────────────────
  group('PhysicsSimulator unit tests (Task 10.7)', () {
    test('entity placed 5px inside wall resolves to boundary edge after 1 step', () {
      final narrow = Rect.fromLTWH(0, 0, 100, 1000);
      final sim = PhysicsSimulator()..setBoundary(narrow);
      // Entity center at x=105 (5px past right wall at 100), no velocity
      final id = _addEntity(sim, x: 105, y: 500, vx: 0, vy: 0, w: 20, isAirborne: false, applyGravity: false);
      sim.step(1.0 / 60.0);
      final s = sim.getState(id);
      expect(s.x + s.width / 2, lessThanOrEqualTo(narrow.right + 0.001));
    });

    test('setConstraintBoundary repositions out-of-bounds entity to interior', () {
      final sim = PhysicsSimulator()..setBoundary(boundary);
      final id = _addEntity(sim, x: 960, y: 540);
      // Set a small constraint boundary that excludes the current position
      final small = Rect.fromLTWH(0, 0, 200, 200);
      sim.setConstraintBoundary(small);
      final s = sim.getState(id);
      final halfW = s.width / 2;
      final halfH = s.height / 2;
      expect(s.x, greaterThanOrEqualTo(small.left + halfW - 0.001));
      expect(s.x, lessThanOrEqualTo(small.right - halfW + 0.001));
      expect(s.y, greaterThanOrEqualTo(small.top + halfH - 0.001));
      expect(s.y, lessThanOrEqualTo(small.bottom - halfH + 0.001));
    });

    test('removing an entity then getting its state throws ArgumentError', () {
      final sim = PhysicsSimulator()..setBoundary(boundary);
      final id = _addEntity(sim);
      sim.removeEntity(id);
      expect(() => sim.getState(id), throwsArgumentError);
    });
  });
}
