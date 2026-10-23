import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import 'package:breakmate/features/companion/behavior/companion_mood_machine.dart';
import 'package:breakmate/features/companion/behavior/cursor_feed.dart';
import 'package:breakmate/features/companion/behavior/gaze_sector.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';

/// Simulates how a small animal attends to a cursor.
///
/// The goal is not to point the eyes at the mouse — that reads as a security
/// camera. Real animals flick their eyes to a target and hold, let the head
/// catch up afterwards, lose interest in things that stop moving, startle at
/// sudden motion nearby, and doze off when the room goes quiet. All of that is
/// here, driven by one cursor feed and a fixed-step integrator so the motion
/// is identical whether the window runs at 60 Hz or 120.
///
/// Attach with [start], feed the pet's on-screen rectangle through
/// [setViewport], and read [snapshot] each frame.
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

  /// Honours the platform's reduce-motion setting: the pet still reacts, but
  /// without bounce, recoil, shake, breathing or wandering glances.
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

  /// Called when something outside the simulation changed state and a host
  /// that stopped its ticker while the pet was [isSettled] should start again.
  VoidCallback? onNeedsFrames;

  /// Which of the nine sectors the pet is currently looking toward.
  GazeDirection get gazeDirection => _sectors.direction;

  /// The explicit mood the face is wearing, before drive-based baselines.
  CompanionMood get mood => _machine.mood;

  /// Whether reactions may move the body at all.
  bool get _motionAllowed => !_reducedMotion && _animations;

  /// Whether motion is permitted to run on its own (breathing, glances).
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

  /// Applies the user's companion preferences. Only the fields passed change.
  ///
  /// Safe to call repeatedly with the same values; nothing is restarted unless
  /// something actually changed.
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

  /// Pauses or resumes the simulation and its claim on the cursor feed, for a
  /// window that is hidden, occluded, or whose host is asleep.
  void setSuspended(bool suspended) {
    if (_suspended == suspended) return;
    _suspended = suspended;
    _syncCursorSubscription();
    if (!suspended) reconcile();
  }

  /// Brings state back into line after the host was suspended or the displays
  /// changed. Animation callbacks may not have run during that time, so
  /// nothing is assumed about them.
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

  /// The pointer is over the pet's own window, as reported by the window
  /// system rather than the global cursor feed, so it works with cursor
  /// following switched off.
  void hover(bool inside) {
    _post(
      inside ? CompanionEvent.pointerEntered : CompanionEvent.pointerExited,
    );
  }

  /// How long a host should wait between ticks right now.
  ///
  /// A calm pet only breathes, which is invisible at 15 frames a second, so
  /// drawing it any faster burns battery on nothing. Anything with real motion
  /// gets 30.
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

  /// The pet's break was completed.
  void onBreakCompleted() {
    onBreakTaken();
    _post(CompanionEvent.breakCompleted);
  }

  /// A break is starting or being suggested.
  void onBreakReminder() => _post(CompanionEvent.breakReminder);

  void _post(CompanionEvent event) {
    if (_machine.post(event, _clock) && _running) {
      _emotion = _resolveEmotion();
      _publish();
    }
    onNeedsFrames?.call();
  }

  /// Where the pet's eyes are, in the same space as the viewport.
  ///
  /// Gaze is measured from here, not from the middle of the window: the head
  /// sits above the body, and looking from the wrong point makes a pet whose
  /// cursor is level with its face appear to look down.
  Offset get _eye {
    if (_eyeOverride != null) return _eyeOverride!;
    return Offset(
      _viewport.center.dx,
      _viewport.top + _viewport.height * _defaultEyeFraction,
    );
  }

  Offset? _eyeOverride;
  static const double _defaultEyeFraction = 0.46;

  // ── Tuning ────────────────────────────────────────────────────────────────

  /// Simulation step. Small enough to be smooth, fixed so behaviour does not
  /// change with the display's refresh rate.
  static const double _step = 1 / 60.0;

  /// Distance in logical pixels at which the cursor stops being interesting.
  double get _interestRadius => _gazeSettings.interestRadius;

  /// Within this distance the cursor is "in its face" and gets full attention.
  static const double _intimateRadius = 150.0;

  /// A gaze error past this triggers a saccade instead of smooth pursuit.
  static const double _saccadeThreshold = 0.26;

  /// How long a saccade takes. Real ones are 30–100 ms.
  static const double _saccadeDuration = 0.085;

  /// Quiet time before the pet gets drowsy, then before it falls asleep.
  static const double _drowsyAfter = 75.0;
  static const double _sleepAfter = 140.0;

  /// How long being ignored takes to turn into visible loneliness.
  ///
  /// Long enough that stepping away for a coffee does not produce a sad pet,
  /// short enough that a whole afternoon of neglect shows.
  static const double _lonelyAfter = 45 * 60;

  /// How long an unbroken working stretch takes to show as weariness. Paired
  /// with the break system: this is the pet noticing what BreakMate is for.
  static const double _wearyAfter = 75 * 60;

  /// A cursor sample older than this counts as a cursor holding still.
  ///
  /// The feed slows down and eventually stops sampling when nothing moves, so
  /// "no news" has to mean stillness. Without this the pet goes on believing
  /// the last movement it saw is still happening, and stares forever.
  static const double _staleSampleSeconds = 0.4;

  // ── State ─────────────────────────────────────────────────────────────────

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

  /// How much of a game is still in progress, 1 at the moment of play and
  /// decaying over a minute or two. Long-lived on purpose: petting is a
  /// moment, playing is a mood.
  double _playing = 0.0;

  /// Direction and vigour of self-propelled travel, each axis -1..1. Set by
  /// the wanderer while the window is moving itself across the screen.
  Offset _travel = Offset.zero;
  double _travelPhase = 0.0;

  // The slow drives behind emotion. Unlike arousal and attention, which move
  // second to second, these accumulate over the working day.
  double _affection = 0.0;
  double _loneliness = 0.0;
  double _fatigue = 0.0;
  double _sinceInteraction = 0.0;
  double _sinceBreak = 0.0;
  double _bounceVelocity = 0.0;
  double _bounce = 0.0;

  /// Secondary motion: a head roll that overshoots and rings out after a hop
  /// or a touch, the way a body keeps moving after the thing driving it stops.
  double _wobble = 0.0;
  double _wobbleVelocity = 0.0;

  /// Seconds until the pet does something unprompted: a hop, a shake, a stretch.
  double _idleActionTimer = 6.0;

  /// True while the user has the window in their hand.
  bool _held = false;

  double _accumulator = 0.0;
  Duration _lastTick = Duration.zero;
  bool _running = false;

  PetBehaviorSnapshot _snapshot = const PetBehaviorSnapshot();

  /// The current frame of motion.
  PetBehaviorSnapshot get snapshot => _snapshot;

  /// Whether the simulation is attached to the cursor feed.
  bool get isRunning => _running;

  /// True when nothing on the pet is moving and nothing will start moving by
  /// itself, so a host can drop from a frame ticker to an occasional tick.
  ///
  /// Time still has to pass for the slow parts of the pet (it dozes off, gets
  /// lonely), which is why a settled pet is ticked rarely rather than never.
  /// Any outside input calls [onNeedsFrames] so the host can speed up again.
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

  /// Begins tracking. Safe to call repeatedly.
  void start() {
    if (_running) return;
    _running = true;
    _useGlobalCursor = true;
    _lastTick = Duration.zero;
    _syncCursorSubscription();
  }

  /// Stops tracking and releases the pet's claim on the cursor feed.
  void stop() {
    if (!_running) return;
    _running = false;
    _useGlobalCursor = false;
    _syncCursorSubscription();
  }

  bool _useGlobalCursor = false;

  /// Holds a subscription to the shared cursor feed exactly when one is
  /// useful: running, looking at the pointer, and not suspended. Without the
  /// subscription the feed stops polling the platform altogether.
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

  /// Tells the engine where the pet currently sits on screen.
  ///
  /// Everything about attention is relative to this rectangle, so it has to be
  /// kept current as the window moves.
  ///
  /// [eye] is where the eyes are in that space, when the host knows; otherwise
  /// they are assumed to sit a little above the middle of the rectangle.
  void setViewport(Rect viewport, {Offset? eye}) {
    if (viewport != _viewport) {
      // A different place on screen (dragged, wandered, new display) means
      // the old sector no longer describes where the pointer is.
      _sectors.reset();
    }
    _viewport = viewport;
    _eyeOverride = eye;
  }

  /// Advances the simulation. Drive this from a [Ticker].
  void tick(Duration elapsed) {
    if (!_running) return;

    var delta = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    // A hitch, a resumed window, or the first frame. Skipping keeps the pet
    // from teleporting through a hundred steps at once.
    // A settled pet is ticked a few times a second, so a longer gap is normal
    // there and is simulated in full.
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

  /// The user touched the pet.
  void pet() {
    _post(CompanionEvent.clicked);
    _delight = 1.0;
    _attention = 1.0;
    _arousal = math.min(1.0, _arousal + 0.45);
    _quietSeconds = 0.0;
    // Affection builds with repeated attention rather than maxing on one
    // touch, so a pet that is looked after looks different from one that was
    // clicked once.
    _affection = math.min(1.0, _affection + 0.35);
    _loneliness = math.max(0.0, _loneliness - 0.5);
    _sinceInteraction = 0.0;
    if (!_reducedMotion && _animations) _bounceVelocity = -150.0;
    _rock(3.5);
    _wake();
  }

  /// The user started a game.
  ///
  /// Unlike [pet], this leaves a mood behind rather than a moment: the pet
  /// stays wound up for a good while afterwards, which is what makes playing
  /// feel like a different act from touching it.
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

  /// The user offered a treat.
  ///
  /// Warmer than a pet and slower to fade — being fed is the thing an animal
  /// remembers about you.
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

  /// A single hop, for effects that need the pet to move in time with
  /// something drawn on screen. Silent under reduced motion.
  void hop(double strength) {
    onNeedsFrames?.call();
    if (!_motionAllowed) return;
    _bounceVelocity = -strength;
    _rock(strength / 40);
  }

  /// Kicks the head roll one way or the other; it rings out on its own.
  void _rock(double impulse) {
    if (!_motionAllowed) return;
    final side = _random.nextBool() ? 1.0 : -1.0;
    _wobbleVelocity += side * impulse;
  }

  /// The user picked the window up. The pet is startled and then hangs there.
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

  /// The window was set down again: a small landing, and relief.
  void release() {
    onNeedsFrames?.call();
    _held = false;
    _delight = math.max(_delight, 0.6);
    if (_motionAllowed) _bounceVelocity = 120.0;
    _rock(5.0);
  }

  /// The user took a break. The companion is glad of it.
  void onBreakTaken() {
    _fatigue = math.max(0.0, _fatigue - 0.6);
    _sinceBreak = 0.0;
    _affection = math.min(1.0, _affection + 0.15);
  }

  /// The pet's current feeling, for the face to wear.
  PetEmotionState get emotion => _emotion;

  /// What the companion would most appreciate right now.
  ///
  /// The face already says how it feels. This exists because feeling and
  /// remedy are not the same question, and a first-time user looking at a
  /// wistful animal has no way to guess that the answer is to touch it.
  PetWish get wish {
    if (_quietSeconds > _drowsyAfter) return PetWish.none;
    // Weariness is measured from how long the *user* has gone without a
    // break, so the companion asking to rest is really asking on their behalf.
    if (_fatigue > 0.45) return PetWish.rest;
    if (_loneliness > 0.4) return PetWish.petting;
    // Already mid-game: it does not need another ball thrown at it.
    if (_playing > 0.2) return PetWish.petting;
    if (_arousal > 0.6) return PetWish.play;
    if (_affection < 0.2) return PetWish.petting;
    return PetWish.treat;
  }

  /// Tells the pet it is moving itself across the screen, at [velocity] in
  /// logical pixels a second.
  ///
  /// Travel is a separate channel from the cursor-driven posture: a creature
  /// crossing a desktop leans into the direction it is going and bobs as it
  /// goes, and without that it reads as a window sliding rather than an
  /// animal walking. Pass [Offset.zero] when it stops.
  void setTravel(Offset velocity) {
    if (_reducedMotion || !_animations) {
      _travel = Offset.zero;
      return;
    }

    final speed = velocity.distance;
    // Below this it is drift, not travel, and leaning into it would just
    // jitter the body.
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

  /// The speed at which travel motion is drawn at full strength.
  static const double _travelFullSpeed = 240.0;

  /// The user did something the pet should notice, without touching it.
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

  /// Feeds a pointer position measured in the same space as [setViewport].
  ///
  /// In-app previews sit inside a window and only ever see local coordinates,
  /// so they drive the pet from their own `MouseRegion` instead of subscribing
  /// to the global cursor. Do not mix the two on one engine — pair this with a
  /// viewport in the same local space and leave [start] unused.
  void pointerMoved(Offset position) {
    final now = DateTime.now();
    var elapsed = now.difference(_lastPointerAt).inMicroseconds / 1e6;
    // Hover events can arrive in bursts. Without a floor, two events in the
    // same millisecond read as a cursor moving thousands of pixels a second
    // and startle the pet for no reason.
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

  /// Runs the simulation without the global cursor feed, for local previews.
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

    // Sudden movement close by is a fright, not an invitation. The pet startles
    // first and works out it was only the cursor afterwards.
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
        // Motion after stillness is the most interesting thing that happens to
        // a pet, so the eyes go before the head does.
        _attention = math.max(_attention, 0.55);
      }
    }
  }

  // ── Simulation ────────────────────────────────────────────────────────────

  void _advance(double dt) {
    _sinceCursorSample += dt;
    _clock += Duration(microseconds: (dt * 1e6).round());
    final reach = math.max(_viewport.longestSide, 1.0);

    final tracking = _hasCursor && !_viewport.isEmpty && _gazeSettings.enabled;
    final toCursor = tracking ? _cursor - _eye : Offset.zero;
    final distance = toCursor.distance;

    _updatePointerProximity(tracking);
    _updateQuietPeriod();
    if (_machine.advance(_clock)) _emotion = _resolveEmotion();

    _updateAttention(dt, distance);
    _updateArousal(dt);
    _updateGazeTarget(dt, toCursor, reach, distance);
    _integrateGaze(dt);
    _integratePosture(dt);
    _updateBlink(dt);
    _updateImpulses(dt);
    _updateDrives(dt);

    if (_idleMotion) {
      _breathPhase += dt * _breathRate();
      if (_breathPhase > math.pi * 2) _breathPhase -= math.pi * 2;
    }
  }

  /// Tells the mood machine when the pointer enters or leaves the pet.
  ///
  /// The enter and exit areas differ in size so a pointer resting on the edge
  /// does not fire an event every frame.
  void _updatePointerProximity(bool tracking) {
    if (!tracking) {
      if (_pointerNear) {
        _pointerNear = false;
        _machine.post(CompanionEvent.pointerExited, _clock);
      }
      return;
    }
    final inside = _pointerNear
        ? _viewport.inflate(36).contains(_cursor)
        : _viewport.inflate(10).contains(_cursor);
    if (inside == _pointerNear) return;
    _pointerNear = inside;
    // Only a pointer that is actually moving is interesting. One that was
    // parked on the pet before it appeared should not make it start.
    if (inside && !_cursorIsStill) {
      _machine.post(CompanionEvent.pointerEntered, _clock);
    } else if (!inside) {
      _machine.post(CompanionEvent.pointerExited, _clock);
    }
  }

  void _updateQuietPeriod() {
    final quiet = _quietSeconds > _drowsyAfter;
    if (quiet == _quietAnnounced) return;
    _quietAnnounced = quiet;
    _machine.post(
      quiet
          ? CompanionEvent.quietPeriodStarted
          : CompanionEvent.quietPeriodEnded,
      _clock,
    );
  }

  /// Whether the cursor should be treated as holding still right now.
  bool get _cursorIsStill =>
      _cursorResting || _sinceCursorSample > _staleSampleSeconds;

  void _updateAttention(double dt, double distance) {
    if (_viewport.isEmpty || !_hasCursor || !_gazeSettings.enabled) {
      _attention = _decay(_attention, 0.5, dt);
      _quietSeconds += dt;
      return;
    }

    // Interest falls off with distance and rises with motion.
    final proximity = distance >= _interestRadius
        ? 0.0
        : 1.0 - (distance / _interestRadius);
    final motion = math.min(1.0, _cursorSpeed / 900.0);

    if (_cursorIsStill) {
      _quietSeconds += dt;
      // Staring at something that has stopped moving gets boring. Interest
      // bleeds away faster than it built, which is what makes the pet look
      // away on its own instead of locking on forever.
      _attention = _decay(_attention, 0.55 + proximity * 0.2, dt);
    } else {
      final pull = proximity * (0.35 + motion * 0.9);
      _attention = math.min(1.0, _attention + pull * dt * 3.2);
    }

    if (distance < _intimateRadius && !_cursorIsStill) {
      _attention = math.max(_attention, 0.9);
    }
  }

  void _updateArousal(double dt) {
    final resting = _quietSeconds > _sleepAfter
        ? 0.04
        : _quietSeconds > _drowsyAfter
        ? 0.14
        : 0.3;
    final target = math.max(
      resting,
      math.max(
        _attention * 0.75,
        math.max(_startle, math.max(_delight, _playing)),
      ),
    );
    // Arousal climbs quickly and settles slowly, like a real startle response.
    final rate = target > _arousal ? 6.0 : 0.55;
    _arousal += (target - _arousal) * math.min(1.0, rate * dt);
  }

  void _updateGazeTarget(
    double dt,
    Offset toCursor,
    double reach,
    double distance,
  ) {
    if (_quietSeconds > _sleepAfter || _machine.mood == CompanionMood.resting) {
      _setGazeTarget(Offset.zero, snap: false);
      return;
    }

    if (_attention > 0.28 &&
        _hasCursor &&
        !_viewport.isEmpty &&
        _gazeSettings.enabled) {
      final sector = _sectors.update(toCursor);
      if (sector == GazeDirection.center) {
        // Inside the dead zone the pointer is "right here". Looking straight
        // ahead reads as relaxed; chasing it around a few pixels does not.
        _setGazeTarget(Offset.zero, snap: false);
      } else {
        // Direction is snapped to the sector so the head does not jitter on a
        // boundary; how far the eyes travel still follows the distance.
        final dead = _gazeSettings.deadZone;
        final span = math.max(reach * 1.25 - dead, 1.0);
        final pull = ((distance - dead) / span).clamp(0.0, 1.0);
        var strength = 0.35 + 0.65 * pull;

        // Close up, the pet looks *at* the cursor rather than toward it.
        if (distance < _intimateRadius) {
          strength = math.min(1.0, strength * 1.2);
        }

        _setGazeTarget(sector.unit * strength, snap: false);
      }
      _idleGazeTimer = 0.9 + _random.nextDouble() * 1.4;
      return;
    }

    // Disengaged. A pointer that has gone quiet is no longer worth following.
    _sectors.reset();
    if (!_idleMotion) {
      _setGazeTarget(Offset.zero, snap: false);
      return;
    }

    // Look around on its own schedule.
    _idleGazeTimer -= dt;
    if (_idleGazeTimer <= 0) {
      _idleGazeTimer = 1.4 + _random.nextDouble() * 3.0;
      final drowsy = _quietSeconds > _drowsyAfter;
      final spread = drowsy ? 0.25 : 0.62;
      _setGazeTarget(
        Offset(
          (_random.nextDouble() * 2 - 1) * spread,
          (_random.nextDouble() * 2 - 1) * spread * 0.55 +
              (drowsy ? 0.25 : 0.0),
        ),
        snap: false,
      );
    }
  }

  void _setGazeTarget(Offset target, {required bool snap}) {
    if (snap) {
      _gaze = target;
      _gazeTarget = target;
      _saccadeT = 1.0;
      return;
    }

    final error = (target - _gazeTarget).distance;
    _gazeTarget = target;

    // Big jumps are made with a saccade; small corrections are tracked
    // smoothly. Doing both is what separates a living eye from a lerp.
    if (error > _saccadeThreshold && _saccadeT >= 1.0 && !_reducedMotion) {
      _saccadeFrom = _gaze;
      _saccadeT = 0.0;
      // Eyes and lids are wired together — a large saccade often carries a
      // blink with it.
      if (_random.nextDouble() < 0.28 && _blinkProgress < 0) {
        _blinkProgress = 0.0;
      }
    }
  }

  void _integrateGaze(double dt) {
    if (_saccadeT < 1.0) {
      _saccadeT = math.min(1.0, _saccadeT + dt / _saccadeDuration);
      // Ease-out: a saccade leaves fast and arrives gently.
      final t = 1 - math.pow(1 - _saccadeT, 3).toDouble();
      _gaze = Offset(
        _saccadeFrom.dx + (_gazeTarget.dx - _saccadeFrom.dx) * t,
        _saccadeFrom.dy + (_gazeTarget.dy - _saccadeFrom.dy) * t,
      );
      return;
    }

    // Smooth pursuit, with gain rising as the pet pays more attention.
    final gain = 3.0 + _attention * 7.0;
    final k = math.min(1.0, gain * dt);
    _gaze = Offset(
      _gaze.dx + (_gazeTarget.dx - _gaze.dx) * k,
      _gaze.dy + (_gazeTarget.dy - _gaze.dy) * k,
    );
  }

  void _integratePosture(double dt) {
    // The head chases the eyes, the body chases the head, each softer than the
    // last. That ordering is the whole trick behind the motion reading as one
    // creature rather than three sliding parts.
    final headTarget = _gaze * (0.55 + _attention * 0.3);
    final headResult = _spring(
      _head,
      _headVelocity,
      headTarget,
      stiffness: 95.0,
      damping: 15.5,
      dt: dt,
    );
    _head = headResult.$1;
    _headVelocity = headResult.$2;

    final bodyTarget = _head * (0.3 + _arousal * 0.15);
    final bodyResult = _spring(
      _body,
      _bodyVelocity,
      bodyTarget,
      stiffness: 38.0,
      damping: 11.0,
      dt: dt,
    );
    _body = bodyResult.$1;
    _bodyVelocity = bodyResult.$2;

    // A curious head cocks to one side. Tie it to how far the pet is reaching
    // sideways, plus a little of its own drift.
    final drift = _idleMotion ? 1.0 : 0.0;
    final tiltTarget = _attention > 0.5
        ? _head.dx * 0.16 + math.sin(_breathPhase * 0.37) * 0.02 * drift
        : math.sin(_breathPhase * 0.31) * 0.03 * drift;
    _tilt += (tiltTarget - _tilt) * math.min(1.0, 3.0 * dt);
  }

  void _updateBlink(double dt) {
    if (_machine.mood == CompanionMood.resting) {
      _blink = 0.0;
      _blinkProgress = -1.0;
      return;
    }
    if (_quietSeconds > _sleepAfter) {
      _blink += (1.0 - _blink) * math.min(1.0, 2.5 * dt);
      return;
    }
    if (_quietSeconds > _drowsyAfter) {
      // Heavy lids, but still blinking occasionally.
      final droop = 0.45;
      if (_blinkProgress < 0) {
        _blink += (droop - _blink) * math.min(1.0, 2.0 * dt);
      }
    }

    if (_blinkProgress >= 0) {
      _blinkProgress += dt;
      const close = 0.045;
      const hold = 0.03;
      const open = 0.085;
      const total = close + hold + open;

      double value;
      if (_blinkProgress < close) {
        value = _blinkProgress / close;
      } else if (_blinkProgress < close + hold) {
        value = 1.0;
      } else if (_blinkProgress < total) {
        value = 1.0 - (_blinkProgress - close - hold) / open;
      } else {
        value = 0.0;
        _blinkProgress = -1.0;
        _blinkTimer = _nextBlinkDelay();
      }
      _blink = math.max(_blink, value.clamp(0.0, 1.0));
      if (_blinkProgress < 0) {
        _blink = _quietSeconds > _drowsyAfter ? 0.45 : 0.0;
      }
      return;
    }

    // With idle animation off the lids stay still unless an event asks.
    if (!_idleMotion) return;
    _blinkTimer -= dt;
    if (_blinkTimer <= 0) _blinkProgress = 0.0;
  }

  /// Blink spacing is irregular in life, so draw it from an exponential
  /// distribution rather than a fixed interval, with a floor so two blinks
  /// never run together.
  double _nextBlinkDelay() {
    final u = 1.0 - _random.nextDouble();
    final mean = _arousal > 0.7 ? 2.6 : 4.2;
    return 1.1 + -math.log(u) * mean;
  }

  void _updateImpulses(double dt) {
    _updateWobble(dt);
    _updateIdleAction(dt);
    _startle = _decay(_startle, _held ? 0.0 : 2.4, dt);
    _delight = _decay(_delight, 1.6, dt);
    // Much slower than the others: a game lasts, where a touch is over as
    // soon as the hand lifts. This rate keeps the pet visibly excited for
    // about forty seconds after a game and calm again within two minutes.
    _playing = _decay(_playing, 0.04, dt);

    // The walk cycle runs faster the harder the pet is travelling, and stops
    // dead when it is not.
    _travelPhase += dt * (5.5 + 7.0 * _travel.distance);

    if (_reducedMotion || !_animations) {
      _bounce = 0.0;
      _bounceVelocity = 0.0;
      return;
    }

    // A spring back to rest, so a pet lands and settles instead of snapping.
    const stiffness = 210.0;
    const damping = 14.0;
    _bounceVelocity += (-stiffness * _bounce - damping * _bounceVelocity) * dt;
    _bounce += _bounceVelocity * dt;
    if (_bounce.abs() < 0.05 && _bounceVelocity.abs() < 0.5) {
      _bounce = 0.0;
      _bounceVelocity = 0.0;
    }
  }

  void _updateWobble(double dt) {
    if (!_motionAllowed) {
      _wobble = 0.0;
      _wobbleVelocity = 0.0;
      return;
    }
    // A held pet dangles and swings; otherwise a lightly damped spring rings
    // the roll out over about a second.
    final target = _held ? math.sin(_clock.inMilliseconds / 260.0) * 0.12 : 0.0;
    _wobbleVelocity +=
        ((target - _wobble) * 120.0 - _wobbleVelocity * 5.5) * dt;
    _wobble += _wobbleVelocity * dt;
    if ((_wobble - target).abs() < 0.0008 && _wobbleVelocity.abs() < 0.01) {
      _wobble = target;
      _wobbleVelocity = 0.0;
    }
  }

  /// Now and then, with nobody touching it, the pet does something of its own:
  /// a small hop, a shake of the head, a stretch. This is what separates a
  /// living thing sitting there from a picture that breathes.
  void _updateIdleAction(double dt) {
    if (!_idleMotion || _held) return;
    if (_quietSeconds > _drowsyAfter) return; // Dozing pets do not fidget.
    _idleActionTimer -= dt;
    if (_idleActionTimer > 0) return;
    _idleActionTimer = 7.0 + _random.nextDouble() * 12.0;

    switch (_random.nextInt(4)) {
      case 0:
        _bounceVelocity = -70.0;
        _rock(2.5);
      case 1:
        _rock(6.0); // A quick shake of the head.
      case 2:
        _bounceVelocity = 40.0; // A stretch: sinks, then rises.
        _attention = math.max(_attention, 0.5);
      default:
        _rock(3.0);
        _idleGazeTimer = 0.0; // Looks somewhere else.
    }
  }

  /// Advances the slow feelings: affection fades, loneliness grows while
  /// ignored, weariness grows while working without a break.
  void _updateDrives(double dt) {
    _sinceInteraction += dt;
    _sinceBreak += dt;

    // Affection fades over roughly half an hour untended, so the warm face is
    // earned rather than permanent.
    _affection = math.max(0.0, _affection - dt / 1800);

    if (_sinceInteraction > _lonelyAfter) {
      _loneliness = math.min(1.0, _loneliness + dt / _lonelyAfter);
    } else {
      _loneliness = math.max(0.0, _loneliness - dt / 600);
    }

    // Weariness only accrues while the user is actually at the machine; a
    // laptop asleep overnight should not tire the pet out.
    if (!_cursorIsStill && _sinceBreak > _wearyAfter) {
      _fatigue = math.min(1.0, _fatigue + dt / _wearyAfter);
    } else if (_cursorIsStill) {
      _fatigue = math.max(0.0, _fatigue - dt / 3600);
    }

    _emotion = _resolveEmotion();
  }

  /// Picks the single feeling the face should wear.
  ///
  /// Ordered by urgency rather than magnitude: a fright interrupts everything,
  /// and sleep beats any feeling the pet had before it dropped off. Only one
  /// emotion shows at a time, because a face blending three of them reads as
  /// none of them.
  PetEmotionState _resolveEmotion() {
    PetEmotionState state(PetEmotion emotion, double intensity) =>
        PetEmotionState(
          emotion: emotion,
          intensity: intensity.clamp(0.0, 1.0),
          affection: _affection,
          loneliness: _loneliness,
          fatigue: _fatigue,
        );

    // The mood machine owns every event-driven feeling. The ladder below only
    // fills in the slow, drive-based baseline when no reaction is showing.
    final mood = _machine.mood;
    if (mood == CompanionMood.resting) {
      return state(mood.emotion, mood.intensity);
    }
    if (mood == CompanionMood.surprised) {
      return state(PetEmotion.startled, math.max(_startle, mood.intensity));
    }
    // A game outranks everything except a fright, and outlasts it too.
    if (_playing > 0.2) {
      return state(PetEmotion.playful, 0.55 + _playing * 0.45);
    }
    // Rapid attention winds the pet up past mere contentment: it laughs.
    if (_delight > 0.25 && _arousal > 0.78) {
      return state(PetEmotion.laughing, 0.7 + _delight * 0.3);
    }
    if (mood == CompanionMood.happy ||
        mood == CompanionMood.encouraging ||
        mood == CompanionMood.attentive) {
      return state(mood.emotion, mood.intensity);
    }
    if (_quietSeconds > _sleepAfter) return state(PetEmotion.sleepy, 1.0);
    if (_delight > 0.25) {
      return state(PetEmotion.affectionate, 0.6 + _delight * 0.4);
    }
    if (_quietSeconds > _drowsyAfter) {
      return state(PetEmotion.sleepy, 0.55);
    }
    if (_fatigue > 0.45) return state(PetEmotion.weary, _fatigue);
    if (_loneliness > 0.4) return state(PetEmotion.lonely, _loneliness);
    if (_attention > 0.75 && _arousal > 0.7) {
      return state(PetEmotion.excited, _arousal);
    }
    if (_affection > 0.35) {
      return state(PetEmotion.happy, 0.45 + _affection * 0.55);
    }
    if (mood == CompanionMood.curious) {
      return state(PetEmotion.curious, math.max(_attention, mood.intensity));
    }
    if (_attention > 0.45) return state(PetEmotion.curious, _attention);
    return state(PetEmotion.content, 0.35 + _affection * 0.3);
  }

  PetEmotionState _emotion = PetEmotionState.neutral;

  double _breathRate() {
    if (_quietSeconds > _sleepAfter) return 1.05;
    if (_quietSeconds > _drowsyAfter) return 1.5;
    return 2.0 + _arousal * 2.6;
  }

  PetActivity _activity() {
    if (_quietSeconds > _sleepAfter) return PetActivity.sleeping;
    if (_delight > 0.25) return PetActivity.delighted;
    if (_startle > 0.25) return PetActivity.startled;
    if (_playing > 0.2) return PetActivity.playful;
    if (_quietSeconds > _drowsyAfter) return PetActivity.drowsy;
    if (_attention > 0.75 && _arousal > 0.72) return PetActivity.playful;
    if (_attention > 0.5) return PetActivity.watching;
    if (_attention > 0.22) return PetActivity.curious;
    return PetActivity.idle;
  }

  void _publish() {
    final breath = math.sin(_breathPhase);
    final startleRecoil = _motionAllowed ? _startle * 8.0 : 0.0;
    final delightLift = _motionAllowed ? _delight * 6.0 : 0.0;

    // Travel rides on top of the cursor-driven posture rather than replacing
    // it, so a pet crossing the screen can still glance at where the pointer
    // went. The bob is what sells it as steps rather than a slide.
    final travelVigour = _travel.distance;
    final trot = travelVigour == 0
        ? 0.0
        : math.sin(_travelPhase) * 3.4 * travelVigour;

    final previous = _snapshot;
    _snapshot = PetBehaviorSnapshot(
      gaze: _gaze,
      headTurn: _head,
      bodyLean: Offset(
        (_body.dx + _travel.dx * 0.55).clamp(-1.0, 1.0),
        (_body.dy + _travel.dy * 0.3).clamp(-1.0, 1.0),
      ),
      blink: _blink.clamp(0.0, 1.0),
      breath: breath,
      bounce: _bounce - delightLift + startleRecoil - trot.abs(),
      squash: !_motionAllowed
          ? 1.0
          : 1.0 +
                (_idleMotion ? breath * 0.012 : 0.0) +
                _delight * 0.05 -
                _startle * 0.03 +
                // Squash and stretch: narrower and taller in the air, wider
                // and shorter as it lands. This is most of what makes a hop
                // read as a body rather than a sticker moving up and down.
                (_bounce * 0.0045).clamp(-0.14, 0.16),
      tilt: _tilt + _travel.dx * 0.11 + _wobble,
      arousal: _arousal.clamp(0.0, 1.0),
      attention: _attention.clamp(0.0, 1.0),
      activity: _activity(),
      emotion: _emotion,
      gazeDirection: _sectors.direction,
      mood: _machine.mood,
    );
    // A pet that has settled produces identical frames. Telling listeners
    // anyway would rebuild and repaint the avatar for nothing.
    if (_visiblySame(previous, _snapshot)) return;
    notifyListeners();
  }

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

  // ── Helpers ───────────────────────────────────────────────────────────────

  static double _decay(double value, double rate, double dt) {
    final next = value - value * rate * dt;
    return next.abs() < 0.001 ? 0.0 : next;
  }

  /// One step of a damped spring, returning the new position and velocity.
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
