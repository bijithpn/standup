import 'dart:math' as math;
import 'dart:ui';

import 'package:breakmate/core/events/app_events.dart';
import 'package:breakmate/core/events/event_bus.dart';
import 'package:breakmate/core/utils/logger.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/physics_simulator.dart';

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
  static const double fetchReturnRadius = 25.0;

  static const double throwableSize = 20.0;

  final PhysicsSimulator _physics;
  final EventBus _eventBus;
  final AppLogger _logger;

  final List<_ThrowableRecord> _throwables = [];
  int _spawnCounter = 0;

  PhysicsEntityId? spawnThrowable(
    Offset releasePoint,
    Offset dragVector, {
    String kind = 'ball',
    Offset? returnTarget,
    double? customSize,
  }) {
    final double magnitude = dragVector.distance;
    if (magnitude < minDragMagnitude) {
      _logger.info(
        'ThrowableObjectManager: drag too short (${magnitude.toStringAsFixed(1)} px), ignoring',
      );
      return null;
    }

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

    final Offset direction = dragVector / magnitude;
    final double speed = math.min(magnitude * velocityScaleFactor, maxVelocity);
    final Offset initialVelocity = direction * speed;

    final double entitySize = customSize ?? throwableSize;
    final PhysicsEntityId physicsId = _physics.addEntity(
      PhysicsEntity(
        initialState: PhysicsEntityState(
          x: releasePoint.dx,
          y: releasePoint.dy,
          vx: initialVelocity.dx,
          vy: initialVelocity.dy,
          width: entitySize,
          height: entitySize,
          isAirborne: true,
          isStationary: false,
          stationaryTicks: 0,
        ),
      ),
    );

    final int priority = _spawnCounter++;
    final record = _ThrowableRecord(
      spawnPriority: priority,
      spawnOrigin: returnTarget ?? releasePoint,
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

  void tick(double dt, {required Rect petBounds, required Offset petAnchor}) {
    final DateTime now = DateTime.now();

    for (int i = 0; i < _throwables.length; i++) {
      final record = _throwables[i];
      if (record.lifecycle == ThrowableLifecycle.disposed) continue;

      PhysicsEntityState state;
      try {
        state = _physics.getState(record.physicsId);
      } catch (_) {
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
          if (record.stationaryAt != null &&
              now.difference(record.stationaryAt!).inSeconds >=
                  stationaryDisposalSeconds) {
            _disposeThrowable(i);
            break;
          }

          final double horizontalDist =
              (petAnchor.dx - throwableBounds.center.dx).abs();
          final double verticalDist = (petAnchor.dy - throwableBounds.center.dy)
              .abs();
          if (horizontalDist <=
                  (petBounds.width / 2 + throwableBounds.width / 2 + 8.0) &&
              verticalDist <=
                  (petBounds.height / 2 + throwableBounds.height / 2 + 25.0)) {
            if (record.kind == 'treat') {
              _eventBus.emit(ThrowableEatenEvent(objectId: record.physicsId));
              _disposeThrowable(i);
            } else {
              _throwables[i] = record.withLifecycle(
                ThrowableLifecycle.beingFetched,
              );
              _eventBus.emit(ThrowableFetchedEvent(objectId: record.physicsId));
              _logger.info(
                'ThrowableObjectManager: throwable ${record.physicsId} being fetched',
              );
            }
          }

        case ThrowableLifecycle.beingFetched:
          final double distToOrigin = (petAnchor - record.spawnOrigin).distance;
          if (distToOrigin <= fetchReturnRadius) {
            _eventBus.emit(ThrowableReturnedEvent(objectId: record.physicsId));
            _disposeThrowable(i);
          }

        case ThrowableLifecycle.disposed:
          break;
      }
    }

    _throwables.removeWhere((r) => r.lifecycle == ThrowableLifecycle.disposed);
  }

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
