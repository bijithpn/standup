import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/services/companion_window_manager.dart';

/// What PetWanderer moves: a window abstraction so wandering can be tested without a real window.
abstract class WanderTarget {
  Size get size;

  Offset get position;

  Future<Offset> readPosition();

  Future<void> moveTo(Offset position);

  void persist();

  Future<List<Rect>> displays();
}

class WindowWanderTarget implements WanderTarget {
  WindowWanderTarget(this._manager);

  final CompanionWindowManager _manager;

  @override
  Size get size => _manager.currentSize;

  @override
  Offset get position => _manager.currentPosition;

  @override
  Future<Offset> readPosition() => _manager.getPosition();

  @override
  Future<void> moveTo(Offset position) => _manager.moveTo(position);

  @override
  void persist() => _manager.persistPosition();

  @override
  Future<List<Rect>> displays() async {
    final manager = _manager.displayManager;
    if (manager == null) return const <Rect>[];
    final displays = await manager.enumerateDisplays();
    return <Rect>[for (final display in displays) display.rect];
  }
}

/// Makes the companion window periodically walk to a nearby point on screen, easing along a path while feeding travel to the engine.
class PetWanderer {
  PetWanderer({
    required WanderTarget target,
    required PetBehaviorEngine engine,
    math.Random? random,
    this.onArrived,
  }) : _target = target,
       _engine = engine,
       _random = random ?? math.Random();

  factory PetWanderer.forWindow({
    required CompanionWindowManager windowManager,
    required PetBehaviorEngine engine,
    math.Random? random,
    VoidCallback? onArrived,
  }) {
    return PetWanderer(
      target: WindowWanderTarget(windowManager),
      engine: engine,
      random: random,
      onArrived: onArrived,
    );
  }

  final WanderTarget _target;
  final PetBehaviorEngine _engine;
  final math.Random _random;

  final VoidCallback? onArrived;

  static const Duration tickInterval = Duration(milliseconds: 40);
  static const double _dt = 0.04;

  static const Duration restInterval = Duration(milliseconds: 500);
  static const double _restDt = 0.5;
  bool _fastTicking = true;

  static const double minDwellSeconds = 45;
  static const double maxDwellSeconds = 170;

  static const double _minHop = 70;
  static const double _maxHop = 280;

  static const double _minWorthwhileHop = 36;

  static const double _speed = 165;
  static const double _minJourneySeconds = 0.7;
  static const double _maxJourneySeconds = 3.2;

  static const double edgeMargin = 18;

  static const double _boundsTtlSeconds = 45;

  static const double _retrySeconds = 6;

  bool _enabled = true;
  bool _running = false;
  bool _suspended = false;
  bool _awaitingPlatform = false;

  double _dwellRemaining = 0;
  double _boundsAge = 0;
  Rect? _bounds;

  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  Offset _lastPosition = Offset.zero;
  double _elapsed = 0;
  double _duration = 0;

  Timer? _timer;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (value) {
      _scheduleDwell();
    } else {
      _abandonJourney();
    }
  }

  bool get isTravelling => _duration > 0;

  @visibleForTesting
  Offset? get destination => isTravelling ? _to : null;

  void start() {
    if (_running) return;
    _running = true;
    _scheduleDwell();
    _fastTicking = false;
    _startTimer(restInterval);
  }

  void _startTimer(Duration interval) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _onTimer());
  }

  void _onTimer() {
    tick(_fastTicking ? _dt : _restDt);
    final needsFast = _duration > 0 || _awaitingPlatform;
    if (needsFast != _fastTicking) {
      _fastTicking = needsFast;
      _startTimer(needsFast ? tickInterval : restInterval);
    }
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    _abandonJourney();
  }

  void suspend() {
    if (_suspended) return;
    _suspended = true;
    _abandonJourney();
  }

  void resume() {
    if (!_suspended) return;
    _suspended = false;

    _scheduleDwell();
  }

  void dispose() {
    stop();
  }

  @visibleForTesting
  void tick([double dt = _dt]) {
    if (_duration > 0) {
      _advanceJourney(dt);
      return;
    }

    _boundsAge += dt;
    if (!_enabled || _suspended) return;

    _dwellRemaining -= dt;
    if (_dwellRemaining > 0) return;

    if (!wantsToMove) {
      _dwellRemaining = _retrySeconds;
      return;
    }

    unawaited(beginJourney());
  }

  // Only wanders when the pet is calm: awake, low attention/arousal and not startled/delighted.
  @visibleForTesting
  bool get wantsToMove {
    final snapshot = _engine.snapshot;

    if (!snapshot.isAwake) return false;

    if (snapshot.attention > 0.35) return false;
    if (snapshot.arousal > 0.6) return false;
    if (snapshot.activity == PetActivity.startled) return false;
    if (snapshot.activity == PetActivity.delighted) return false;

    return true;
  }

  /// Picks a destination within display bounds and starts easing toward it; _awaitingPlatform guards overlapping async window reads.
  @visibleForTesting
  Future<void> beginJourney() async {
    if (_awaitingPlatform) return;
    _awaitingPlatform = true;

    try {
      final bounds = await _resolveBounds();
      final size = _target.size;
      if (bounds == null || bounds.width <= size.width) {
        _scheduleDwell();
        return;
      }

      final origin = await _readPosition();
      final target = pickTarget(origin, bounds, size);

      if ((target - origin).distance < _minWorthwhileHop) {
        _scheduleDwell();
        return;
      }

      if (_suspended || !_enabled) {
        _scheduleDwell();
        return;
      }

      _from = origin;
      _to = target;
      _lastPosition = origin;
      _elapsed = 0;
      _duration = ((target - origin).distance / _speed).clamp(
        _minJourneySeconds,
        _maxJourneySeconds,
      );
    } catch (_) {
      _scheduleDwell();
    } finally {
      _awaitingPlatform = false;
    }
  }

  void _advanceJourney(double dt) {
    if (_suspended || !_enabled) {
      _abandonJourney();
      return;
    }

    _elapsed += dt;
    final t = (_elapsed / _duration).clamp(0.0, 1.0);
    final position = Offset.lerp(_from, _to, _ease(t))!;

    _engine.setTravel((position - _lastPosition) / dt);
    _lastPosition = position;

    if (!_awaitingPlatform) {
      _awaitingPlatform = true;
      unawaited(
        _target.moveTo(position).whenComplete(() => _awaitingPlatform = false),
      );
    }

    if (t >= 1.0) _settle();
  }

  /// Ends the journey, persists the new window position and schedules the next dwell.
  void _settle() {
    _duration = 0;
    _elapsed = 0;
    _engine.setTravel(Offset.zero);
    _target.persist();
    _scheduleDwell();
    onArrived?.call();
  }

  void _abandonJourney() {
    if (_duration == 0) return;
    _settle();
  }

  void _scheduleDwell() {
    _dwellRemaining =
        minDwellSeconds +
        _random.nextDouble() * (maxDwellSeconds - minDwellSeconds);
  }

  @visibleForTesting
  Offset pickTarget(Offset origin, Rect bounds, Size size) {
    final minX = bounds.left + edgeMargin;
    final minY = bounds.top + edgeMargin;
    final maxX = math.max(minX, bounds.right - size.width - edgeMargin);
    final maxY = math.max(minY, bounds.bottom - size.height - edgeMargin);

    final angle = _random.nextDouble() * math.pi * 2;
    final hop = _minHop + _random.nextDouble() * (_maxHop - _minHop);

    var dx = math.cos(angle) * hop;
    final dy = math.sin(angle) * hop * 0.45;

    final centreX = (minX + maxX) / 2;
    final towardNearestEdge = origin.dx < centreX ? -1.0 : 1.0;
    dx += towardNearestEdge * hop * 0.35;

    return Offset(
      (origin.dx + dx).clamp(minX, maxX),
      (origin.dy + dy).clamp(minY, maxY),
    );
  }

  Future<Rect?> _resolveBounds() async {
    final cached = _bounds;
    if (cached != null && _boundsAge < _boundsTtlSeconds) return cached;

    final displays = await _target.displays();
    if (displays.isEmpty) return null;

    final size = _target.size;
    final centre = _target.position + Offset(size.width / 2, size.height / 2);

    var best = displays.first;
    for (final display in displays) {
      if (display.contains(centre)) {
        best = display;
        break;
      }
    }

    _bounds = best;
    _boundsAge = 0;
    return best;
  }

  Future<Offset> _readPosition() async {
    try {
      return await _target.readPosition();
    } catch (_) {
      return _target.position;
    }
  }

  static double _ease(double t) => t * t * (3 - 2 * t);
}
