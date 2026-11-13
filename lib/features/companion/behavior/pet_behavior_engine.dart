import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import 'package:breakmate/features/companion/behavior/companion_mood_machine.dart';
import 'package:breakmate/features/companion/behavior/cursor_feed.dart';
import 'package:breakmate/features/companion/behavior/gaze_sector.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';

part 'pet_behavior_simulation.dart';

/// Drives the avatar's procedural life (gaze, blink, breathing, spring wobble, mood) at a fixed step from a ticker and publishes a PetBehaviorSnapshot.
class PetBehaviorEngine extends ChangeNotifier {
  PetBehaviorEngine({
    CursorFeed? cursorFeed,
    math.Random? random,
    bool reducedMotion = false,
    GazeSettings gaze = const GazeSettings(),
  }) : _cursorFeed = cursorFeed ?? CursorFeed.instance,
       _random = random ?? math.Random(),
       _reducedMotion = reducedMotion,
       _gazeSettings = gaze {
    _sectors.deadZone = gaze.deadZone;
    _machine = CompanionMoodMachine(config: _moodConfig());
  }

  final CursorFeed _cursorFeed;
  final math.Random _random;

  bool get reducedMotion => _reducedMotion;
  bool _reducedMotion;

  GazeSettings _gazeSettings;
  bool _idleAnimation = true;
  bool _reactions = true;
  bool _animations = true;
  bool _interactions = true;
  bool _suspended = false;

  final GazeSectorTracker _sectors = GazeSectorTracker();
  late CompanionMoodMachine _machine;
  Duration _clock = Duration.zero;
  bool _pointerNear = false;
  bool _quietAnnounced = false;

  VoidCallback? onNeedsFrames;

  GazeDirection get gazeDirection => _sectors.direction;

  CompanionMood get mood => _machine.mood;

  bool get _motionAllowed => !_reducedMotion && _animations;

  bool get _idleMotion =>
      _idleAnimation &&
      !_reducedMotion &&
      _animations &&
      _machine.mood != CompanionMood.resting;

  CompanionMoodConfig _moodConfig() => CompanionMoodConfig(
    animationsEnabled: _animations,
    reactionsEnabled: _reactions,
    interactionsEnabled: _interactions,
  );

  void configure({
    GazeSettings? gaze,
    bool? idleAnimation,
    bool? reactions,
    bool? animations,
    bool? interactions,
    bool? reducedMotion,
  }) {
    var moodChanged = false;
    if (gaze != null && gaze != _gazeSettings) {
      _gazeSettings = gaze;
      _sectors.deadZone = gaze.deadZone;
      if (!gaze.enabled) _sectors.reset();
      _syncCursorSubscription();
    }
    if (idleAnimation != null) _idleAnimation = idleAnimation;
    if (reactions != null && reactions != _reactions) {
      _reactions = reactions;
      moodChanged = true;
    }
    if (animations != null && animations != _animations) {
      _animations = animations;
      moodChanged = true;
    }
    if (interactions != null && interactions != _interactions) {
      _interactions = interactions;
      moodChanged = true;
    }
    if (reducedMotion != null) _reducedMotion = reducedMotion;
    if (moodChanged) _machine.configure(_moodConfig());
    if (_running) {
      _emotion = _resolveEmotion();
      _publish();
    }
    onNeedsFrames?.call();
  }

  /// Pauses cursor polling (e.g. window hidden) and reconciles state on resume.
  void setSuspended(bool suspended) {
    if (_suspended == suspended) return;
    _suspended = suspended;
    _syncCursorSubscription();
    if (!suspended) reconcile();
  }

  /// Clears transient tracking state after a gap so the next tick does not integrate a huge dt.
  void reconcile() {
    _lastTick = Duration.zero;
    _accumulator = 0.0;
    _sinceCursorSample = 0.0;
    _hasCursor = false;
    _pointerNear = false;
    _sectors.reset();
    _quietAnnounced = false;
    _machine.reconcile(_clock);
    onNeedsFrames?.call();
  }

  void hover(bool inside) {
    _post(
      inside ? CompanionEvent.pointerEntered : CompanionEvent.pointerExited,
    );
  }

  Duration get frameInterval => _isCalm
      ? const Duration(milliseconds: 66)
      : const Duration(milliseconds: 33);

  bool get _isCalm =>
      _attention < 0.1 &&
      _saccadeT >= 1.0 &&
      _blinkProgress < 0 &&
      _startle == 0.0 &&
      _delight == 0.0 &&
      _playing == 0.0 &&
      _bounce == 0.0 &&
      _travel == Offset.zero &&
      (_gaze - _gazeTarget).distance < 0.02 &&
      _headVelocity.distance < 0.05;

  void onBreakCompleted() {
    onBreakTaken();
    _post(CompanionEvent.breakCompleted);
  }

  void onBreakReminder() => _post(CompanionEvent.breakReminder);

  void _post(CompanionEvent event) {
    if (_machine.post(event, _clock) && _running) {
      _emotion = _resolveEmotion();
      _publish();
    }
    onNeedsFrames?.call();
  }

  Offset get _eye {
    if (_eyeOverride != null) return _eyeOverride!;
    return Offset(
      _viewport.center.dx,
      _viewport.top + _viewport.height * _defaultEyeFraction,
    );
  }

  Offset? _eyeOverride;
  static const double _defaultEyeFraction = 0.46;

  static const double _step = 1 / 60.0;

  double get _interestRadius => _gazeSettings.interestRadius;

  static const double _intimateRadius = 150.0;

  static const double _saccadeThreshold = 0.26;

  static const double _saccadeDuration = 0.085;

  static const double _drowsyAfter = 75.0;
  static const double _sleepAfter = 140.0;

  static const double _lonelyAfter = 45 * 60;

  static const double _wearyAfter = 75 * 60;

  static const double _staleSampleSeconds = 0.4;

  StreamSubscription<CursorSample>? _cursorSub;
  Rect _viewport = Rect.zero;

  Offset _cursor = Offset.zero;
  double _cursorSpeed = 0.0;
  bool _cursorResting = true;
  bool _hasCursor = false;
  double _sinceCursorSample = 0.0;

  Offset _gaze = Offset.zero;
  Offset _gazeTarget = Offset.zero;
  Offset _saccadeFrom = Offset.zero;
  double _saccadeT = 1.0;

  Offset _head = Offset.zero;
  Offset _headVelocity = Offset.zero;
  Offset _body = Offset.zero;
  Offset _bodyVelocity = Offset.zero;

  double _attention = 0.0;
  double _arousal = 0.3;
  double _quietSeconds = 0.0;
  double _breathPhase = 0.0;
  double _tilt = 0.0;

  double _blink = 0.0;
  double _blinkTimer = 2.5;
  double _blinkProgress = -1.0;

  double _idleGazeTimer = 1.5;
  double _startle = 0.0;
  double _delight = 0.0;

  double _playing = 0.0;

  Offset _travel = Offset.zero;
  double _travelPhase = 0.0;

  double _affection = 0.0;
  double _loneliness = 0.0;
  double _fatigue = 0.0;
  double _sinceInteraction = 0.0;
  double _sinceBreak = 0.0;
  double _bounceVelocity = 0.0;
  double _bounce = 0.0;

  double _wobble = 0.0;
  double _wobbleVelocity = 0.0;

  double _idleActionTimer = 6.0;

  bool _held = false;

  double _accumulator = 0.0;
  Duration _lastTick = Duration.zero;
  bool _running = false;

  PetBehaviorSnapshot _snapshot = const PetBehaviorSnapshot();

  PetBehaviorSnapshot get snapshot => _snapshot;

  bool get isRunning => _running;

  bool get isSettled {
    if (_suspended) return true;
    if (_idleMotion) return false;
    const eps = 0.004;
    return _saccadeT >= 1.0 &&
        (_gaze - _gazeTarget).distance < eps &&
        (_head - _gaze * (0.55 + _attention * 0.3)).distance < eps &&
        _headVelocity.distance < 0.01 &&
        _bodyVelocity.distance < 0.01 &&
        _blinkProgress < 0 &&
        _bounce == 0.0 &&
        _bounceVelocity == 0.0 &&
        _wobble == 0.0 &&
        _wobbleVelocity == 0.0 &&
        _startle == 0.0 &&
        _delight == 0.0 &&
        _playing == 0.0 &&
        _travel == Offset.zero;
  }

  /// Starts the engine and subscribes to the global cursor feed (if gaze is enabled).
  void start() {
    if (_running) return;
    _running = true;
    _useGlobalCursor = true;
    _lastTick = Duration.zero;
    _syncCursorSubscription();
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _useGlobalCursor = false;
    _syncCursorSubscription();
  }

  bool _useGlobalCursor = false;

  void _syncCursorSubscription() {
    final wanted =
        _running && _useGlobalCursor && _gazeSettings.enabled && !_suspended;
    if (wanted && _cursorSub == null) {
      _cursorSub = _cursorFeed.subscribe(_onCursor);
    } else if (!wanted && _cursorSub != null) {
      _cursorSub!.cancel();
      _cursorSub = null;
      _hasCursor = false;
    }
  }

  /// Sets the on-screen rect of the pet so cursor positions can be turned into gaze; eye overrides the pet's eye position.
  void setViewport(Rect viewport, {Offset? eye}) {
    if (viewport != _viewport) {
      _sectors.reset();
    }
    _viewport = viewport;
    _eyeOverride = eye;
  }

  /// Fixed-timestep loop: accumulates elapsed time and runs _advance per step; caps steps/delta so a stalled frame cannot spiral.
  void tick(Duration elapsed) {
    if (!_running) return;

    var delta = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final settled = isSettled;
    if (delta <= 0 || delta > (settled ? 1.0 : 0.25)) delta = _step;

    _accumulator += delta;
    var steps = 0;
    final maxSteps = settled ? 60 : 6;
    while (_accumulator >= _step && steps < maxSteps) {
      _advance(_step);
      _accumulator -= _step;
      steps++;
    }
    if (steps == 0) return;

    _publish();
  }

  void pet() {
    _post(CompanionEvent.clicked);
    _delight = 1.0;
    _attention = 1.0;
    _arousal = math.min(1.0, _arousal + 0.45);
    _quietSeconds = 0.0;

    _affection = math.min(1.0, _affection + 0.35);
    _loneliness = math.max(0.0, _loneliness - 0.5);
    _sinceInteraction = 0.0;
    if (!_reducedMotion && _animations) _bounceVelocity = -150.0;
    _rock(3.5);
    _wake();
  }

  void play() {
    _playing = 1.0;
    _attention = 1.0;
    _arousal = 1.0;
    _quietSeconds = 0.0;
    _affection = math.min(1.0, _affection + 0.2);
    _loneliness = math.max(0.0, _loneliness - 0.6);
    _sinceInteraction = 0.0;
    if (!_reducedMotion && _animations) _bounceVelocity = -260.0;
    _rock(9.0);
    _wake();
  }

  void feed() {
    _delight = 1.0;
    _attention = 1.0;
    _arousal = math.min(1.0, _arousal + 0.3);
    _quietSeconds = 0.0;
    _affection = math.min(1.0, _affection + 0.5);
    _loneliness = 0.0;
    _sinceInteraction = 0.0;
    if (!_reducedMotion && _animations) _bounceVelocity = -110.0;
    _rock(2.0);
    _wake();
  }

  void hop(double strength) {
    onNeedsFrames?.call();
    if (!_motionAllowed) return;
    _bounceVelocity = -strength;
    _rock(strength / 40);
  }

  void _rock(double impulse) {
    if (!_motionAllowed) return;
    final side = _random.nextBool() ? 1.0 : -1.0;
    _wobbleVelocity += side * impulse;
  }

  void grab() {
    onNeedsFrames?.call();
    _held = true;
    _startle = 1.0;
    _attention = 1.0;
    _arousal = math.min(1.0, _arousal + 0.4);
    _quietSeconds = 0.0;
    _rock(7.0);
    _wake();
  }

  void release() {
    onNeedsFrames?.call();
    _held = false;
    _delight = math.max(_delight, 0.6);
    if (_motionAllowed) _bounceVelocity = 120.0;
    _rock(5.0);
  }

  void onBreakTaken() {
    _fatigue = math.max(0.0, _fatigue - 0.6);
    _sinceBreak = 0.0;
    _affection = math.min(1.0, _affection + 0.15);
  }

  PetEmotionState get emotion => _emotion;

  PetWish get wish {
    if (_quietSeconds > _drowsyAfter) return PetWish.none;

    if (_fatigue > 0.45) return PetWish.rest;
    if (_loneliness > 0.4) return PetWish.petting;

    if (_playing > 0.2) return PetWish.petting;
    if (_arousal > 0.6) return PetWish.play;
    if (_affection < 0.2) return PetWish.petting;
    return PetWish.treat;
  }

  /// Fed by PetWanderer with the window's movement so the body leans and trots while the window walks.
  void setTravel(Offset velocity) {
    if (_reducedMotion || !_animations) {
      _travel = Offset.zero;
      return;
    }

    final speed = velocity.distance;

    if (speed < 6) {
      _travel = Offset.zero;
      return;
    }

    final vigour = (speed / _travelFullSpeed).clamp(0.0, 1.0);
    _travel = Offset(
      velocity.dx / speed * vigour,
      velocity.dy / speed * vigour,
    );
  }

  static const double _travelFullSpeed = 240.0;

  void nudge() {
    onNeedsFrames?.call();
    _attention = math.max(_attention, 0.8);
    _arousal = math.min(1.0, _arousal + 0.2);
    _quietSeconds = 0.0;
    _sinceInteraction = 0.0;
    _loneliness = math.max(0.0, _loneliness - 0.15);
    _wake();
  }

  void _wake() {
    if (_quietSeconds > _drowsyAfter) _quietSeconds = 0.0;
  }

  void pointerMoved(Offset position) {
    final now = DateTime.now();
    var elapsed = now.difference(_lastPointerAt).inMicroseconds / 1e6;

    if (elapsed < _step || elapsed > 0.5) elapsed = _step;
    _lastPointerAt = now;

    final delta = position - _cursor;
    final speed = delta.distance / elapsed;

    _onCursor(
      CursorSample(
        position: position,
        velocity: delta / elapsed,
        isResting: speed < 4.0,
        timestamp: now,
      ),
    );
  }

  DateTime _lastPointerAt = DateTime.fromMillisecondsSinceEpoch(0);

  void startLocal() {
    _running = true;
    _useGlobalCursor = false;
    _lastTick = Duration.zero;
  }

  void _onCursor(CursorSample sample) {
    if (!_gazeSettings.enabled || _suspended) return;
    final wasResting = _cursorResting;
    _cursor = sample.position;
    _cursorSpeed = sample.speed;
    _cursorResting = sample.isResting;
    _hasCursor = true;
    _sinceCursorSample = 0.0;

    if (_viewport.isEmpty) return;

    final distance = (sample.position - _eye).distance;

    if (!_reducedMotion &&
        _animations &&
        distance < _intimateRadius * 1.6 &&
        sample.speed > 1900 &&
        _startle < 0.3) {
      _startle = 1.0;
      _arousal = math.min(1.0, _arousal + 0.5);
      _post(CompanionEvent.suddenMotion);
    }

    if (!sample.isResting) {
      _quietSeconds = 0.0;
      if (wasResting && distance < _interestRadius) {
        _attention = math.max(_attention, 0.55);
      }
    }
  }

  PetEmotionState _emotion = PetEmotionState.neutral;

  // Used by _publish to skip notifyListeners when nothing perceptible changed.
  static bool _visiblySame(PetBehaviorSnapshot a, PetBehaviorSnapshot b) {
    const eps = 0.0005;
    return (a.gaze - b.gaze).distance < eps &&
        (a.headTurn - b.headTurn).distance < eps &&
        (a.bodyLean - b.bodyLean).distance < eps &&
        (a.blink - b.blink).abs() < eps &&
        (a.breath - b.breath).abs() < eps &&
        (a.bounce - b.bounce).abs() < 0.01 &&
        (a.squash - b.squash).abs() < eps &&
        (a.tilt - b.tilt).abs() < eps &&
        a.activity == b.activity &&
        a.emotion.emotion == b.emotion.emotion &&
        (a.emotion.intensity - b.emotion.intensity).abs() < 0.01;
  }

  static double _decay(double value, double rate, double dt) {
    final next = value - value * rate * dt;
    return next.abs() < 0.001 ? 0.0 : next;
  }

  static (Offset, Offset) _spring(
    Offset current,
    Offset velocity,
    Offset target, {
    required double stiffness,
    required double damping,
    required double dt,
  }) {
    final ax = (target.dx - current.dx) * stiffness - velocity.dx * damping;
    final ay = (target.dy - current.dy) * stiffness - velocity.dy * damping;
    final nextVelocity = Offset(velocity.dx + ax * dt, velocity.dy + ay * dt);
    return (
      Offset(
        current.dx + nextVelocity.dx * dt,
        current.dy + nextVelocity.dy * dt,
      ),
      nextVelocity,
    );
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
