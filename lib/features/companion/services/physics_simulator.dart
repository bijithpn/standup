import 'dart:math' as math;
import 'dart:ui';

import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';

class PhysicsEntity {
  const PhysicsEntity({required this.initialState, this.applyGravity = true});

  final PhysicsEntityState initialState;
  final bool applyGravity;
}

class PhysicsSimulator {
  static const double gravity = 980.0;
  static const double frictionDecay = 0.85;
  static const double restitution = 0.6;
  static const double stationaryThreshold = 5.0;
  static const int stationaryTickCount = 3;

  int _nextId = 0;
  final Map<PhysicsEntityId, _EntityRecord> _entities = {};

  Rect _boundary = Rect.zero;
  Rect? _constraintBounds;

  PhysicsEntityId addEntity(PhysicsEntity entity) {
    final id = _nextId++;
    _entities[id] = _EntityRecord(
      state: entity.initialState,
      applyGravity: entity.applyGravity,
    );
    return id;
  }

  void removeEntity(PhysicsEntityId id) {
    _entities.remove(id);
  }

  PhysicsEntityState getState(PhysicsEntityId id) {
    final record = _entities[id];
    if (record == null) {
      throw ArgumentError('PhysicsSimulator: unknown entity id $id');
    }
    return record.state;
  }

  void setBoundary(Rect boundary) {
    _boundary = boundary;
    _clampAllEntitiesToBoundary();
  }

  void setConstraintBoundary(Rect? constraintBounds) {
    _constraintBounds = constraintBounds;
    _clampAllEntitiesToBoundary();
  }

  void setEntityGravity(PhysicsEntityId id, {required bool applyGravity}) {
    final record = _entities[id];
    if (record != null) {
      _entities[id] = record.withGravity(applyGravity);
    }
  }

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

    if (applyGravity && isAirborne) {
      vy = vy + gravity * dt;
    }

    if (!isAirborne) {
      final double decay = math.pow(frictionDecay, dt) as double;
      vx = vx * decay;
      vy = vy * decay;
    }

    x = x + vx * dt;
    y = y + vy * dt;

    bool landedThisTick = false;

    final double halfW = s.width / 2.0;
    if (x - halfW < bounds.left) {
      x = bounds.left + halfW;
      if (vx < 0) vx = -vx * restitution;
    }
    if (x + halfW > bounds.right) {
      x = bounds.right - halfW;
      if (vx > 0) vx = -vx * restitution;
    }
    final double halfH = s.height / 2.0;
    if (y - halfH < bounds.top) {
      y = bounds.top + halfH;
      if (vy < 0) vy = -vy * restitution;
    }
    if (y + halfH > bounds.bottom) {
      y = bounds.bottom - halfH;
      if (vy > 0) vy = -vy * restitution;
      if (isAirborne) {
        isAirborne = false;
        landedThisTick = true;
      }
    }

    if (!isAirborne && y + halfH < bounds.bottom) {
      isAirborne = true;
    }

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

    x = x.clamp(bounds.left + halfW, bounds.right - halfW);
    y = y.clamp(bounds.top + halfH, bounds.bottom - halfH);

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

class _EntityRecord {
  const _EntityRecord({required this.state, required this.applyGravity});

  final PhysicsEntityState state;
  final bool applyGravity;

  _EntityRecord withGravity(bool applyGravity) =>
      _EntityRecord(state: state, applyGravity: applyGravity);
}
