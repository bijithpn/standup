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

  PetEmotionState _emotion = PetEmotionState.neutral;

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
