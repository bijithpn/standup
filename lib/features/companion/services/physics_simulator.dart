import 'dart:math' as math;
import 'dart:ui';

import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';

// ---------------------------------------------------------------------------
// PhysicsEntity — input descriptor for registration
// ---------------------------------------------------------------------------

/// Descriptor used to register a new entity in [PhysicsSimulator].
///
/// [initialState] provides the starting position and velocity.
/// [applyGravity] should be `false` for the pet entity when it is in any
/// state other than `falling` (navigation owns the position in those states).
class PhysicsEntity {
  const PhysicsEntity({required this.initialState, this.applyGravity = true});

  final PhysicsEntityState initialState;
  final bool applyGravity;
}

// ---------------------------------------------------------------------------
// PhysicsSimulator
// ---------------------------------------------------------------------------

/// Fixed 60 Hz deterministic physics engine for the pet and throwable objects.
///
/// All arithmetic uses IEEE 754 `double` operations applied in a fixed order.
/// There is no `DateTime.now()`, no `Random`, and no I/O inside [step].
///
/// Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 7.2, 7.3
class PhysicsSimulator {
  static const double gravity = 980.0; // logical px/s²
  static const double frictionDecay = 0.85; // per second on surface contact
  static const double restitution = 0.6; // bounce coefficient
  static const double stationaryThreshold = 5.0; // px/s both axes
  static const int stationaryTickCount = 3; // consecutive ticks needed

  // ---- Internal state -------------------------------------------------------

  int _nextId = 0;
  final Map<PhysicsEntityId, _EntityRecord> _entities = {};

  Rect _boundary = Rect.zero;
  Rect? _constraintBounds; // null = free roam

  // ---- Public API -----------------------------------------------------------

  /// Register a new physics entity and return its opaque ID.
  PhysicsEntityId addEntity(PhysicsEntity entity) {
    final id = _nextId++;
    _entities[id] = _EntityRecord(
      state: entity.initialState,
      applyGravity: entity.applyGravity,
    );
    return id;
  }

  /// Remove an entity from the simulation.
  void removeEntity(PhysicsEntityId id) {
    _entities.remove(id);
  }

  /// Return an immutable snapshot of the entity's current physics state.
  ///
  /// Throws [ArgumentError] if [id] is not registered.
  PhysicsEntityState getState(PhysicsEntityId id) {
    final record = _entities[id];
    if (record == null) {
      throw ArgumentError('PhysicsSimulator: unknown entity id $id');
    }
    return record.state;
  }

  /// Update the movement boundary (called on display change).
  ///
  /// Any entity currently outside the new bounds is clamped to the nearest
  /// boundary point while preserving its velocity.
  void setBoundary(Rect boundary) {
    _boundary = boundary;
    _clampAllEntitiesToBoundary();
  }

  /// Update the constraint boundary (null = free roam).
  ///
  /// When non-null the constraint boundary is used instead of [_boundary].
  void setConstraintBoundary(Rect? constraintBounds) {
    _constraintBounds = constraintBounds;
    _clampAllEntitiesToBoundary();
  }

  /// Set the gravity flag for a specific entity (used to toggle gravity for
  /// the pet entity when it transitions in/out of the `falling` state).
  void setEntityGravity(PhysicsEntityId id, {required bool applyGravity}) {
    final record = _entities[id];
    if (record != null) {
      _entities[id] = record.withGravity(applyGravity);
    }
  }

  /// Advance all entities by [dt] seconds.
  ///
  /// Pure function behaviour: given identical initial states and [dt], the
  /// outputs are bit-identical (deterministic, requirement 9.7).
  void step(double dt) {
    if (dt <= 0) return;
    final Rect activeBounds = _constraintBounds ?? _boundary;

    for (final entry in _entities.entries) {
      _entities[entry.key] = _EntityRecord(
        state: _stepEntity(
          entry.value.state,
          dt,
          activeBounds,
          entry.value.applyGravity,
        ),
        applyGravity: entry.value.applyGravity,
      );
    }
  }

  // ---- Private step logic ---------------------------------------------------

  /// Advance a single entity one tick.  All arithmetic in fixed IEEE 754 order.
  static PhysicsEntityState _stepEntity(
    PhysicsEntityState s,
    double dt,
    Rect bounds,
    bool applyGravity,
  ) {
    double x = s.x;
    double y = s.y;
    double vx = s.vx;
    double vy = s.vy;
    bool isAirborne = s.isAirborne;
    bool isStationary = s.isStationary;
    int stationaryTicks = s.stationaryTicks;

    // 1. Gravity (only when airborne and gravity is enabled).
    if (applyGravity && isAirborne) {
      vy = vy + gravity * dt; // fixed order: vy first
    }

    // 2. Friction (only when in surface contact).
    if (!isAirborne) {
      final double decay = math.pow(frictionDecay, dt) as double;
      vx = vx * decay;
      vy = vy * decay;
    }

    // 3. Integrate position.
    x = x + vx * dt;
    y = y + vy * dt;

    // 4. Boundary collision resolution.
    // Each edge: detect penetration, resolve, reflect velocity with restitution.
    bool landedThisTick = false;

    // Left edge
    final double halfW = s.width / 2.0;
    if (x - halfW < bounds.left) {
      x = bounds.left + halfW;
      if (vx < 0) vx = -vx * restitution;
    }
    // Right edge
    if (x + halfW > bounds.right) {
      x = bounds.right - halfW;
      if (vx > 0) vx = -vx * restitution;
    }
    // Top edge
    final double halfH = s.height / 2.0;
    if (y - halfH < bounds.top) {
      y = bounds.top + halfH;
      if (vy < 0) vy = -vy * restitution;
    }
    // Bottom edge (floor)
    if (y + halfH > bounds.bottom) {
      y = bounds.bottom - halfH;
      if (vy > 0) vy = -vy * restitution;
      if (isAirborne) {
        isAirborne = false;
        landedThisTick = true;
      }
    }

    // Detect if entity has left the floor (airborne check).
    if (!isAirborne && y + halfH < bounds.bottom) {
      isAirborne = true;
    }

    // 5. Stationary detection.
    if (vx.abs() < stationaryThreshold && vy.abs() < stationaryThreshold) {
      stationaryTicks = stationaryTicks + 1;
      if (stationaryTicks >= stationaryTickCount) {
        vx = 0.0;
        vy = 0.0;
        isStationary = true;
      }
    } else {
      stationaryTicks = 0;
      isStationary = false;
    }

    // 6. Hard clamp to boundary (last resort).
    x = x.clamp(bounds.left + halfW, bounds.right - halfW);
    y = y.clamp(bounds.top + halfH, bounds.bottom - halfH);

    // If entity just landed, mark it as not airborne.
    if (landedThisTick) isAirborne = false;

    return PhysicsEntityState(
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      width: s.width,
      height: s.height,
      isAirborne: isAirborne,
      isStationary: isStationary,
      stationaryTicks: stationaryTicks,
    );
  }

  // ---- Helpers --------------------------------------------------------------

  void _clampAllEntitiesToBoundary() {
    final Rect activeBounds = _constraintBounds ?? _boundary;
    if (activeBounds == Rect.zero) return;

    for (final entry in _entities.entries) {
      final s = entry.value.state;
      final double halfW = s.width / 2.0;
      final double halfH = s.height / 2.0;
      final double clampedX = s.x.clamp(
        activeBounds.left + halfW,
        activeBounds.right - halfW,
      );
      final double clampedY = s.y.clamp(
        activeBounds.top + halfH,
        activeBounds.bottom - halfH,
      );
      if (clampedX != s.x || clampedY != s.y) {
        _entities[entry.key] = _EntityRecord(
          state: s.copyWith(x: clampedX, y: clampedY),
          applyGravity: entry.value.applyGravity,
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Internal record
// ---------------------------------------------------------------------------

/// Internal mutable record associating a [PhysicsEntityState] with its
/// gravity flag.  Immutable — replaced on each step.
class _EntityRecord {
  const _EntityRecord({required this.state, required this.applyGravity});

  final PhysicsEntityState state;
  final bool applyGravity;

  _EntityRecord withGravity(bool applyGravity) =>
      _EntityRecord(state: state, applyGravity: applyGravity);
}
