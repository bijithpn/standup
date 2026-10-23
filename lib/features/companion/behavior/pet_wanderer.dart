import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/services/companion_window_manager.dart';

/// The window, as the wanderer needs to see it.
///
/// A deliberately tiny surface. Everything behind it is a platform call, and
/// the interesting part of wandering — when to go, where to, how it gets there
/// — is arithmetic that should not need a desktop to exercise.
abstract class WanderTarget {
  /// The window's size in logical pixels.
  Size get size;

  /// The last known position, without asking the platform.
  Offset get position;

  /// Asks the platform where the window actually is.
  Future<Offset> readPosition();

  /// Moves the window. Must not persist anything or clamp to a display; the
  /// wanderer has already done both.
  Future<void> moveTo(Offset position);

  /// Records the current position as the one to restore on next launch.
  void persist();

  /// The rectangles the window is allowed to sit in.
  Future<List<Rect>> displays();
}

/// [WanderTarget] backed by the real companion window.
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

/// Lets the companion take itself for a walk.
///
/// A pet that never leaves the corner you dropped it in is furniture. Every so
/// often — when it is awake, calm, and not being looked at — this picks a spot
/// a short hop away and eases the window over to it.
///
/// The restraint is the whole design. It only moves while idle, never while
/// the pointer is near or the user is interacting, never further than a few
/// hundred pixels at a time, and it drifts toward the edges of the display
/// rather than the middle, because a window that parks itself over someone's
/// work is not charming. It stops the moment anything more interesting
/// happens.
class PetWanderer {
  PetWanderer({
    required WanderTarget target,
    required PetBehaviorEngine engine,
    math.Random? random,
    this.onArrived,
  }) : _target = target,
       _engine = engine,
       _random = random ?? math.Random();

  /// The wanderer for the real companion window.
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

  /// Called once the window has settled, so the owner can resync whatever it
  /// tracks about where the window is.
  final VoidCallback? onArrived;

  /// How often the wanderer thinks. Also the frame rate of a journey — fast
  /// enough to look continuous, slow enough that the platform call to move a
  /// window is not being made sixty times a second.
  static const Duration tickInterval = Duration(milliseconds: 40);
  static const double _dt = 0.04;

  /// While the pet is dwelling nothing moves, so the loop only needs to notice
  /// that the dwell has run out. A coarse tick keeps the timer from waking the
  /// app 25 times a second for the minute or two between walks.
  static const Duration restInterval = Duration(milliseconds: 500);
  static const double _restDt = 0.5;
  bool _fastTicking = true;

  /// The window sits still for somewhere in this range between walks.
  static const double minDwellSeconds = 45;
  static const double maxDwellSeconds = 170;

  /// How far one hop travels. Short on purpose: a pet crosses a desk, it does
  /// not teleport across a monitor.
  static const double _minHop = 70;
  static const double _maxHop = 280;

  /// Anything shorter than this is not worth the move.
  static const double _minWorthwhileHop = 36;

  /// Walking pace, logical pixels a second.
  static const double _speed = 165;
  static const double _minJourneySeconds = 0.7;
  static const double _maxJourneySeconds = 3.2;

  /// Clearance kept between the window and the edge of the display.
  static const double edgeMargin = 18;

  /// How long a cached display rectangle is trusted. Monitors get plugged in.
  static const double _boundsTtlSeconds = 45;

  /// How long to wait before reconsidering when the pet is busy. Short, so a
  /// companion that happens to be watching the cursor does not forfeit its
  /// whole turn.
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

  /// Whether wandering is allowed at all. Turning it off mid-walk finishes
  /// nothing — the pet stops where it stands, which is what a user who just
  /// unticked the box is asking for.
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

  /// Whether a walk is in progress.
  bool get isTravelling => _duration > 0;

  /// Where the current walk is headed. Null when it is not walking.
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

  /// The user is interacting — hovering, dragging, clicking. Nothing moves
  /// until they are done, and a walk already under way is abandoned rather
  /// than paused: a window that slides out from under the pointer is a bug as
  /// far as anyone using it is concerned.
  void suspend() {
    if (_suspended) return;
    _suspended = true;
    _abandonJourney();
  }

  void resume() {
    if (!_suspended) return;
    _suspended = false;
    // A fresh dwell, so the pet does not bolt the instant the pointer leaves.
    _scheduleDwell();
  }

  void dispose() {
    stop();
  }

  // ── The loop ──────────────────────────────────────────────────────────────

  /// One step. Driven by the internal timer; exposed so a test can advance it
  /// without waiting in real time.
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

  /// Whether now is a reasonable moment to wander off.
  @visibleForTesting
  bool get wantsToMove {
    final snapshot = _engine.snapshot;

    // Asleep pets stay put.
    if (!snapshot.isAwake) return false;

    // Locked onto the cursor, mid-game, or still recovering from a fright:
    // all of them mean the pet's attention is somewhere it should stay.
    if (snapshot.attention > 0.35) return false;
    if (snapshot.arousal > 0.6) return false;
    if (snapshot.activity == PetActivity.startled) return false;
    if (snapshot.activity == PetActivity.delighted) return false;

    return true;
  }

  /// Chooses a destination and starts moving toward it.
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

      // The user may have grabbed the window while displays were being
      // enumerated. Both of the above are awaits, and either is long enough
      // to matter.
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
      // A display that vanished, a window that is already gone. Try later.
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

    // Velocity comes from the frames actually drawn rather than from the
    // curve's derivative, so the pet's lean matches what the window did even
    // when a frame was dropped.
    _engine.setTravel((position - _lastPosition) / dt);
    _lastPosition = position;

    // One platform move in flight at a time. Queueing them would build a
    // backlog the window then has to chase through after the walk is over.
    if (!_awaitingPlatform) {
      _awaitingPlatform = true;
      unawaited(
        _target.moveTo(position).whenComplete(() => _awaitingPlatform = false),
      );
    }

    if (t >= 1.0) _settle();
  }

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

  // ── Where to go ───────────────────────────────────────────────────────────

  /// Picks the next resting spot.
  ///
  /// Direction is random, but horizontal travel is favoured over vertical and
  /// the whole thing is nudged back toward the nearer side of the display, so
  /// over an afternoon the companion drifts along the edges instead of
  /// settling in the middle of whatever the user is reading.
  @visibleForTesting
  Offset pickTarget(Offset origin, Rect bounds, Size size) {
    final minX = bounds.left + edgeMargin;
    final minY = bounds.top + edgeMargin;
    final maxX = math.max(minX, bounds.right - size.width - edgeMargin);
    final maxY = math.max(minY, bounds.bottom - size.height - edgeMargin);

    final angle = _random.nextDouble() * math.pi * 2;
    final hop = _minHop + _random.nextDouble() * (_maxHop - _minHop);

    // Flattening the vertical component keeps hops looking like a walk along a
    // surface rather than a drift through the air.
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

  /// The display the companion currently sits on, cached briefly.
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

  /// Smoothstep: leaves slowly, arrives slowly, no overshoot.
  static double _ease(double t) => t * t * (3 - 2 * t);
}
