import 'dart:math' as math;
import 'dart:ui';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/physics_simulator.dart';

/// Manages the lifecycle of up to 5 throwable objects.
///
/// Requirements: 7.1, 7.2, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 7.10
class ThrowableObjectManager {
  ThrowableObjectManager({
    required PhysicsSimulator physicsSimulator,
    EventBus? eventBus,
    AppLogger? logger,
  }) : _physics = physicsSimulator,
       _eventBus = eventBus ?? EventBus.instance,
       _logger = logger ?? AppLogger();

  static const int maxActiveThrowables = 5;
  static const double minDragMagnitude = 20.0;
  static const double velocityScaleFactor = 5.0;
  static const double maxVelocity = 2000.0;
  static const double stationaryDisposalSeconds = 30.0;
  static const double unreachableDisposalSeconds = 10.0;
  static const double fetchReturnRadius = 10.0;

  /// Default throwable bounding box size (logical px).
  static const double throwableSize = 20.0;

  final PhysicsSimulator _physics;
  final EventBus _eventBus;
  final AppLogger _logger;

  final List<_ThrowableRecord> _throwables = [];
  int _spawnCounter = 0;

  // ---- Public API -----------------------------------------------------------

  /// Spawn a throwable at [releasePoint] with velocity derived from [dragVector].
  ///
  /// Requirements 7.1, 7.9
  PhysicsEntityId? spawnThrowable(
    Offset releasePoint,
    Offset dragVector, {
    String kind = 'ball',
  }) {
    final double magnitude = dragVector.distance;
    if (magnitude < minDragMagnitude) {
      _logger.info(
        'ThrowableObjectManager: drag too short (${magnitude.toStringAsFixed(1)} px), ignoring',
      );
      return null;
    }

    // Enforce max 5 active throwables (req 7.9).
    final int activeCount = _throwables
        .where((r) => r.lifecycle != ThrowableLifecycle.disposed)
        .length;
    if (activeCount >= maxActiveThrowables) {
      _eventBus.emit(ThrowRejectedEvent());
      _logger.info(
        'ThrowableObjectManager: max throwables reached, throw rejected',
      );
      return null;
    }

    // Compute initial velocity: direction × min(magnitude × scale, 2000).
    final Offset direction = dragVector / magnitude;
    final double speed = math.min(magnitude * velocityScaleFactor, maxVelocity);
    final Offset initialVelocity = direction * speed;

    final PhysicsEntityId physicsId = _physics.addEntity(
      PhysicsEntity(
        initialState: PhysicsEntityState(
          x: releasePoint.dx,
          y: releasePoint.dy,
          vx: initialVelocity.dx,
          vy: initialVelocity.dy,
          width: throwableSize,
          height: throwableSize,
          isAirborne: true,
          isStationary: false,
          stationaryTicks: 0,
        ),
      ),
    );

    final int priority = _spawnCounter++;
    final record = _ThrowableRecord(
      spawnPriority: priority,
      spawnOrigin: releasePoint,
      physicsId: physicsId,
      lifecycle: ThrowableLifecycle.flying,
      kind: kind,
    );
    _throwables.add(record);

    _eventBus.emit(ThrowableSpawnedEvent(objectId: physicsId));
    _logger.info(
      'ThrowableObjectManager: spawned throwable id=$physicsId '
      'priority=$priority speed=${speed.toStringAsFixed(1)}',
    );
    return physicsId;
  }

  /// Tick all active throwables and advance lifecycle state.
  ///
  /// Call once per game tick (60 Hz). [petBounds] is the pet's current bounding
  /// rect; [petAnchor] is the pet's anchor point.
  ///
  /// Requirements: 7.4, 7.6, 7.7, 7.8, 7.10
  void tick(double dt, {required Rect petBounds, required Offset petAnchor}) {
    final DateTime now = DateTime.now();

    for (int i = 0; i < _throwables.length; i++) {
      final record = _throwables[i];
      if (record.lifecycle == ThrowableLifecycle.disposed) continue;

      PhysicsEntityState state;
      try {
        state = _physics.getState(record.physicsId);
      } catch (_) {
        // Entity already removed.
        _throwables[i] = record.withLifecycle(ThrowableLifecycle.disposed);
        continue;
      }

      final Rect throwableBounds = Rect.fromCenter(
        center: Offset(state.x, state.y),
        width: state.width,
        height: state.height,
      );

      switch (record.lifecycle) {
        case ThrowableLifecycle.flying:
          // Transition to stationary when physics reports stationary for ≥3 ticks.
          if (state.isStationary) {
            _throwables[i] = record.copyWith(
              lifecycle: ThrowableLifecycle.stationary,
              stationaryAt: now,
            );
            _eventBus.emit(
              ThrowableStationaryEvent(objectId: record.physicsId),
            );
            _logger.info(
              'ThrowableObjectManager: throwable ${record.physicsId} became stationary',
            );
          }

        case ThrowableLifecycle.stationary:
          // Auto-dispose after 30s stationary (req 7.10).
          if (record.stationaryAt != null &&
              now.difference(record.stationaryAt!).inSeconds >=
                  stationaryDisposalSeconds) {
            _disposeThrowable(i);
            break;
          }

          // Pet overlap → beingFetched (req 7.7).
          if (petBounds.overlaps(throwableBounds)) {
            _throwables[i] = record.withLifecycle(
              ThrowableLifecycle.beingFetched,
            );
            _eventBus.emit(ThrowableFetchedEvent(objectId: record.physicsId));
            _logger.info(
              'ThrowableObjectManager: throwable ${record.physicsId} being fetched',
            );
          }

        case ThrowableLifecycle.beingFetched:
          // Return to origin → disposed (req 7.8).
          final double distToOrigin = (petAnchor - record.spawnOrigin).distance;
          if (distToOrigin <= fetchReturnRadius) {
            _eventBus.emit(ThrowableReturnedEvent(objectId: record.physicsId));
            _disposeThrowable(i);
          }

        case ThrowableLifecycle.disposed:
          break;
      }
    }

    // Prune fully-disposed records from the list to keep it compact.
    _throwables.removeWhere((r) => r.lifecycle == ThrowableLifecycle.disposed);
  }

  /// Return the non-disposed throwable with the highest spawn priority.
  ///
  /// This is the pet's current chase target (req 7.4).
  PhysicsEntityId? get chaseTarget {
    _ThrowableRecord? best;
    for (final r in _throwables) {
      if (r.lifecycle == ThrowableLifecycle.disposed) continue;
      if (best == null || r.spawnPriority > best.spawnPriority) {
        best = r;
      }
    }
    return best?.physicsId;
  }

  /// Public getter exposing the physics ID of the current chase target.
  ///
  /// Equivalent to [chaseTarget].
  PhysicsEntityId? get chaseTargetPhysicsId => chaseTarget;

  List<ThrowableObjectState> snapshots() {
    final result = <ThrowableObjectState>[];
    for (final record in _throwables) {
      if (record.lifecycle == ThrowableLifecycle.disposed) continue;
      final state = _physics.getState(record.physicsId);
      result.add(
        ThrowableObjectState(
          id: record.physicsId,
          spawnPriority: record.spawnPriority,
          spawnOrigin: record.spawnOrigin,
          physicsId: record.physicsId,
          lifecycle: record.lifecycle,
          stationaryTickCount: state.stationaryTicks,
          stationaryAt: record.stationaryAt,
          unreachableSince: record.unreachableSince,
          kind: record.kind,
          position: Offset(state.x, state.y),
        ),
      );
    }
    return result;
  }

  /// Mark a throwable as unreachable (called by navigation layer).
  ///
  /// The manager will dispose it after [unreachableDisposalSeconds].
  void markUnreachable(PhysicsEntityId id) {
    final DateTime now = DateTime.now();
    for (int i = 0; i < _throwables.length; i++) {
      if (_throwables[i].physicsId == id &&
          _throwables[i].lifecycle != ThrowableLifecycle.disposed) {
        if (_throwables[i].unreachableSince == null) {
          _throwables[i] = _throwables[i].copyWith(unreachableSince: now);
        } else if (now.difference(_throwables[i].unreachableSince!).inSeconds >=
            unreachableDisposalSeconds) {
          _disposeThrowable(i);
        }
        return;
      }
    }
  }

  // ---- Private helpers ------------------------------------------------------

  void _disposeThrowable(int index) {
    final record = _throwables[index];
    _physics.removeEntity(record.physicsId);
    _throwables[index] = record.withLifecycle(ThrowableLifecycle.disposed);
    _eventBus.emit(ThrowableDisposedEvent(objectId: record.physicsId));
    _logger.info(
      'ThrowableObjectManager: throwable ${record.physicsId} disposed',
    );
  }
}

// ---------------------------------------------------------------------------
// Internal mutable record
// ---------------------------------------------------------------------------

class _ThrowableRecord {
  const _ThrowableRecord({
    required this.spawnPriority,
    required this.spawnOrigin,
    required this.physicsId,
    required this.lifecycle,
    this.stationaryAt,
    this.unreachableSince,
    this.kind = 'ball',
  });

  final int spawnPriority;
  final Offset spawnOrigin;
  final PhysicsEntityId physicsId;
  final ThrowableLifecycle lifecycle;
  final DateTime? stationaryAt;
  final DateTime? unreachableSince;
  final String kind;

  _ThrowableRecord withLifecycle(ThrowableLifecycle l) => _ThrowableRecord(
    spawnPriority: spawnPriority,
    spawnOrigin: spawnOrigin,
    physicsId: physicsId,
    lifecycle: l,
    stationaryAt: stationaryAt,
    unreachableSince: unreachableSince,
    kind: kind,
  );

  _ThrowableRecord copyWith({
    ThrowableLifecycle? lifecycle,
    DateTime? stationaryAt,
    DateTime? unreachableSince,
  }) => _ThrowableRecord(
    spawnPriority: spawnPriority,
    spawnOrigin: spawnOrigin,
    physicsId: physicsId,
    lifecycle: lifecycle ?? this.lifecycle,
    stationaryAt: stationaryAt ?? this.stationaryAt,
    unreachableSince: unreachableSince ?? this.unreachableSince,
    kind: kind,
  );
}
