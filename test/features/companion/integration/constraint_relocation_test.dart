// Integration test: constrained mode pet relocation.
//
//
//   Pet's current location is outside the new bounds, THEN THE Behavior_Engine
//   SHALL reposition the Pet to the nearest point inside the Constraint_Window
//   bounds within one Tick.
//
// Strategy:
//   Exercise the real PhysicsSimulator + the onBoundsChanged() path of
//   NativeConstraintWindowController (or call setConstraintBoundary() directly
//   the same way onBoundsChanged() does). The relocation is synchronous —
//   setConstraintBoundary() immediately clamps all out-of-bounds entities in
//   _clampAllEntitiesToBoundary(). We verify:
//     1. After calling onBoundsChanged(newBounds), the pet's position returned
//        by getState() is within the new constraint rect.
//     2. The clamped position is the nearest interior point, i.e. it minimises
//        Euclidean distance to the original position among all valid interior
//        positions (equiv. to axis-aligned clamping).
//     3. This holds for three distinct scenarios: pet to the right, pet below,
//        and pet diagonally outside the new bounds.
//
// NativeConstraintWindowController needs NativeBridgePlatform and EventBus
// wired up. To keep the test self-contained we call
// PhysicsSimulator.setConstraintBoundary() directly — that is exactly what
// onBoundsChanged() calls (confirmed in
// lib/features/companion/services/constraint_window_controller.dart).

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/physics_simulator.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Register a pet entity at [x],[y] with size [w]×[h].
PhysicsEntityId _addPet(
  PhysicsSimulator sim, {
  required double x,
  required double y,
  double w = 80,
  double h = 80,
}) {
  return sim.addEntity(
    PhysicsEntity(
      initialState: PhysicsEntityState(
        x: x,
        y: y,
        vx: 0,
        vy: 0,
        width: w,
        height: h,
        isAirborne: false,
        isStationary: true,
        stationaryTicks: 3,
      ),
      applyGravity: false, // navigation owns position; gravity not needed here
    ),
  );
}

/// Returns true when the entity's bounding box is fully inside [bounds].
/// Allows a 1e-6 floating-point tolerance.
bool _isInsideBounds(PhysicsEntityState s, Rect bounds) {
  const tol = 1e-6;
  final halfW = s.width / 2;
  final halfH = s.height / 2;
  return s.x - halfW >= bounds.left - tol &&
      s.x + halfW <= bounds.right + tol &&
      s.y - halfH >= bounds.top - tol &&
      s.y + halfH <= bounds.bottom + tol;
}

/// Compute the expected nearest interior point for an entity at [origX],[origY]
/// with half-extents [halfW],[halfH] constrained to [bounds].
/// This mirrors _clampAllEntitiesToBoundary in PhysicsSimulator.
({double x, double y}) _expectedClamp(
  double origX,
  double origY,
  double halfW,
  double halfH,
  Rect bounds,
) {
  final cx = origX.clamp(bounds.left + halfW, bounds.right - halfW);
  final cy = origY.clamp(bounds.top + halfH, bounds.bottom - halfH);
  return (x: cx, y: cy);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // A large outer boundary so the simulator is initialised properly.
  const outerBoundary = Rect.fromLTWH(0, 0, 1920, 1080);

  group('Requirement 4.6 — pet relocation when constraint window moves', () {
    // -----------------------------------------------------------------------
    // Scenario 1: pet is to the RIGHT of the new constraint rect
    //   Pet starts at (400, 50) with size 80×80.
    //   New constraint bounds: Rect.fromLTWH(0, 0, 100, 100).
    //   Pet center x=400 > bounds.right=100, so it must be clamped left.
    //   Expected nearest x = bounds.right − halfW = 100 − 40 = 60.
    //   Expected nearest y = clamp(50, 40, 60) = 50.
    // -----------------------------------------------------------------------
    test('Scenario 1: pet to the right — repositioned to right interior edge '
        'within one tick', () {
      const petX = 400.0;
      const petY = 50.0;
      const petW = 80.0;
      const petH = 80.0;
      const newBounds = Rect.fromLTWH(0, 0, 100, 100);

      final sim = PhysicsSimulator()..setBoundary(outerBoundary);
      final id = _addPet(sim, x: petX, y: petY, w: petW, h: petH);

      // Simulate what onBoundsChanged() does — update constraint boundary.
      sim.setConstraintBoundary(newBounds);

      // One tick to process (setConstraintBoundary clamps immediately, but
      // step() applies the active bounds as a hard-clamp too).
      sim.step(1 / 60);

      final s = sim.getState(id);

      // Verify: inside new bounds.
      expect(
        _isInsideBounds(s, newBounds),
        isTrue,
        reason:
            'Pet bounding box must be fully inside the new constraint rect '
            'after one tick. Got x=${s.x}, y=${s.y}.',
      );

      // Verify: nearest interior point.
      final expected = _expectedClamp(
        petX,
        petY,
        petW / 2,
        petH / 2,
        newBounds,
      );
      expect(
        s.x,
        closeTo(expected.x, 0.5),
        reason:
            'x should be clamped to nearest interior (expected ${expected.x})',
      );
      expect(
        s.y,
        closeTo(expected.y, 0.5),
        reason:
            'y should be clamped to nearest interior (expected ${expected.y})',
      );
    });

    // -----------------------------------------------------------------------
    // Scenario 2: pet is BELOW the new constraint rect
    //   Pet starts at (50, 400) with size 80×80.
    //   New constraint bounds: Rect.fromLTWH(0, 0, 200, 200).
    //   Pet center y=400 > bounds.bottom=200 — must be clamped up.
    //   Expected nearest x = clamp(50, 40, 160) = 50.
    //   Expected nearest y = bounds.bottom − halfH = 200 − 40 = 160.
    // -----------------------------------------------------------------------
    test('Scenario 2: pet below bounds — repositioned to bottom interior edge '
        'within one tick', () {
      const petX = 50.0;
      const petY = 400.0;
      const petW = 80.0;
      const petH = 80.0;
      const newBounds = Rect.fromLTWH(0, 0, 200, 200);

      final sim = PhysicsSimulator()..setBoundary(outerBoundary);
      final id = _addPet(sim, x: petX, y: petY, w: petW, h: petH);

      sim.setConstraintBoundary(newBounds);
      sim.step(1 / 60);

      final s = sim.getState(id);

      expect(
        _isInsideBounds(s, newBounds),
        isTrue,
        reason:
            'Pet must be inside new constraint bounds after one tick. '
            'Got x=${s.x}, y=${s.y}.',
      );

      final expected = _expectedClamp(
        petX,
        petY,
        petW / 2,
        petH / 2,
        newBounds,
      );
      expect(
        s.x,
        closeTo(expected.x, 0.5),
        reason: 'x should be at nearest interior (expected ${expected.x})',
      );
      expect(
        s.y,
        closeTo(expected.y, 0.5),
        reason: 'y should be clamped to bottom edge (expected ${expected.y})',
      );
    });

    // -----------------------------------------------------------------------
    // Scenario 3: pet is DIAGONALLY outside (both x and y exceed bounds)
    //   Pet starts at (400, 400) with size 80×80.
    //   New constraint bounds: Rect.fromLTWH(0, 0, 100, 100).
    //   Expected: x clamped to 60 (right edge − halfW), y clamped to 60
    //   (bottom edge − halfH) — i.e. nearest corner of the accessible interior.
    // -----------------------------------------------------------------------
    test('Scenario 3: pet diagonally outside — repositioned to nearest corner '
        'of interior within one tick', () {
      const petX = 400.0;
      const petY = 400.0;
      const petW = 80.0;
      const petH = 80.0;
      const newBounds = Rect.fromLTWH(0, 0, 100, 100);

      final sim = PhysicsSimulator()..setBoundary(outerBoundary);
      final id = _addPet(sim, x: petX, y: petY, w: petW, h: petH);

      sim.setConstraintBoundary(newBounds);
      sim.step(1 / 60);

      final s = sim.getState(id);

      expect(
        _isInsideBounds(s, newBounds),
        isTrue,
        reason:
            'Pet must be inside constraint bounds after one tick. '
            'Got x=${s.x}, y=${s.y}.',
      );

      final expected = _expectedClamp(
        petX,
        petY,
        petW / 2,
        petH / 2,
        newBounds,
      );
      // Both axes clamped: expected x=60, y=60.
      expect(
        s.x,
        closeTo(expected.x, 0.5),
        reason: 'x should be at right interior edge (expected ${expected.x})',
      );
      expect(
        s.y,
        closeTo(expected.y, 0.5),
        reason: 'y should be at bottom interior edge (expected ${expected.y})',
      );
    });

    // -----------------------------------------------------------------------
    // Scenario 4: pet already INSIDE the new bounds — no relocation needed.
    //   Verifies the happy-path is not accidentally disrupted.
    // -----------------------------------------------------------------------
    test('Scenario 4: pet already inside new bounds — position unchanged', () {
      const petX = 50.0;
      const petY = 50.0;
      const petW = 80.0;
      const petH = 80.0;
      const newBounds = Rect.fromLTWH(0, 0, 300, 300);

      final sim = PhysicsSimulator()..setBoundary(outerBoundary);
      final id = _addPet(sim, x: petX, y: petY, w: petW, h: petH);

      sim.setConstraintBoundary(newBounds);
      sim.step(1 / 60);

      final s = sim.getState(id);

      expect(
        _isInsideBounds(s, newBounds),
        isTrue,
        reason: 'Pet already inside bounds must remain inside after tick.',
      );

      // Position should not drift significantly (gravity disabled, zero vel).
      expect(
        s.x,
        closeTo(petX, 0.5),
        reason: 'x should be unchanged when pet was already inside bounds',
      );
      expect(
        s.y,
        closeTo(petY, 0.5),
        reason: 'y should be unchanged when pet was already inside bounds',
      );
    });

    // -----------------------------------------------------------------------
    // Scenario 5: relocation happens IMMEDIATELY at setConstraintBoundary()
    //   (before any step is called) — verifying the "within one Tick" contract
    //   is actually satisfied synchronously by setConstraintBoundary().
    // -----------------------------------------------------------------------
    test(
      'Scenario 5: relocation is immediate — pet inside bounds before step()',
      () {
        const petX = 400.0;
        const petY = 400.0;
        const newBounds = Rect.fromLTWH(0, 0, 100, 100);

        final sim = PhysicsSimulator()..setBoundary(outerBoundary);
        final id = _addPet(sim, x: petX, y: petY);

        // Call setConstraintBoundary but do NOT call step().
        sim.setConstraintBoundary(newBounds);

        final s = sim.getState(id);

        expect(
          _isInsideBounds(s, newBounds),
          isTrue,
          reason:
              'setConstraintBoundary() must immediately reposition the pet '
              'to the nearest interior point without requiring a step() call. '
              'Got x=${s.x}, y=${s.y}.',
        );
      },
    );
  });
}
