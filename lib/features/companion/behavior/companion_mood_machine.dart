import 'package:breakmate/features/companion/behavior/pet_emotion.dart';

/// What the companion is doing emotionally, as seen by the person watching it.
///
/// This is a presentation state, not a claim about the user: nothing here is
/// inferred from their face, voice or text. Every transition is caused by an
/// observable [CompanionEvent].
enum CompanionMood {
  /// Relaxed, occasional blink, minimal movement.
  idle(0),

  /// Asleep or drowsy after a long quiet spell. Sustained, not timed.
  sleepy(10),

  /// The pointer came near. Lingers briefly after it leaves.
  curious(20),

  /// A deliberate interaction: the pet was clicked.
  attentive(30),

  /// A relevant break reminder, offered gently.
  encouraging(40),

  /// A break was completed.
  happy(50),

  /// A sudden, meaningful movement close by. Always brief.
  surprised(60),

  /// Deliberately calm: animation or reactions are switched off.
  resting(100);

  const CompanionMood(this.priority);

  /// Higher wins. A lower-priority event never replaces a higher one.
  final int priority;

  /// How long a timed mood lasts before falling back, or null if it persists
  /// until something ends it.
  Duration? get duration => switch (this) {
    CompanionMood.curious => const Duration(milliseconds: 2200),
    CompanionMood.attentive => const Duration(milliseconds: 1400),
    CompanionMood.encouraging => const Duration(milliseconds: 4000),
    CompanionMood.happy => const Duration(milliseconds: 3600),
    CompanionMood.surprised => const Duration(milliseconds: 900),
    CompanionMood.idle || CompanionMood.sleepy || CompanionMood.resting => null,
  };

  /// The face the renderer already knows how to draw for this mood.
  PetEmotion get emotion => switch (this) {
    CompanionMood.idle => PetEmotion.content,
    CompanionMood.sleepy => PetEmotion.sleepy,
    CompanionMood.curious => PetEmotion.curious,
    CompanionMood.attentive => PetEmotion.excited,
    CompanionMood.encouraging => PetEmotion.affectionate,
    CompanionMood.happy => PetEmotion.happy,
    CompanionMood.surprised => PetEmotion.startled,
    CompanionMood.resting => PetEmotion.content,
  };

  /// How strongly the face should show it, 0..1.
  double get intensity => switch (this) {
    CompanionMood.idle => 0.3,
    CompanionMood.sleepy => 0.8,
    CompanionMood.curious => 0.6,
    CompanionMood.attentive => 0.7,
    CompanionMood.encouraging => 0.75,
    CompanionMood.happy => 0.9,
    CompanionMood.surprised => 0.9,
    CompanionMood.resting => 0.2,
  };

  /// Whether this mood is a short-lived reaction rather than a standing state.
  bool get isReaction => duration != null;
}

/// Something that happened that the companion may respond to.
enum CompanionEvent {
  /// The pointer moved into the interaction area.
  pointerEntered,

  /// The pointer left the interaction area.
  pointerExited,

  /// The companion was clicked or tapped.
  clicked,

  /// A break was completed (not skipped).
  breakCompleted,

  /// A break is starting or being suggested.
  breakReminder,

  /// Something moved fast and close by.
  suddenMotion,

  /// No input for the configured quiet period.
  quietPeriodStarted,

  /// Input resumed after a quiet period.
  quietPeriodEnded,
}

/// The rules for which events are heard right now.
class CompanionMoodConfig {
  const CompanionMoodConfig({
    this.animationsEnabled = true,
    this.reactionsEnabled = true,
    this.interactionsEnabled = true,
  });

  /// False puts the companion into [CompanionMood.resting] and ignores
  /// everything except the quiet-period bookkeeping.
  final bool animationsEnabled;

  /// Whether celebratory and surprised reactions (happy, encouraging,
  /// surprised) are shown. Clicks still get an attentive response.
  final bool reactionsEnabled;

  /// Whether pointer proximity and clicks are heard at all.
  final bool interactionsEnabled;

  @override
  bool operator ==(Object other) =>
      other is CompanionMoodConfig &&
      other.animationsEnabled == animationsEnabled &&
      other.reactionsEnabled == reactionsEnabled &&
      other.interactionsEnabled == interactionsEnabled;

  @override
  int get hashCode =>
      Object.hash(animationsEnabled, reactionsEnabled, interactionsEnabled);
}

/// A deterministic, clock-driven state machine from [CompanionEvent]s to a
/// [CompanionMood].
///
/// Holds at most one timed reaction at a time and never owns a timer: the
/// caller passes the current time into [post] and [advance], so there is
/// nothing to leak, nothing to overlap, and tests run without real time.
///
/// Rules:
///  * A reaction only replaces the current one if its priority is higher.
///  * The same reaction arriving again while it is showing does not restart
///    it; [reactionSerial] only changes on a real change of mood.
///  * Sleepy and resting are standing states. Reactions play on top of sleepy
///    and the machine returns to it afterwards.
///  * When a reaction ends the machine falls back to the standing state
///    underneath, so an unrelated state is never reset by a reaction.
class CompanionMoodMachine {
  CompanionMoodMachine({
    CompanionMoodConfig config = const CompanionMoodConfig(),
  }) : _config = config {
    _mood = _standing();
  }

  CompanionMoodConfig _config;
  CompanionMood _mood = CompanionMood.idle;
  Duration? _reactionEndsAt;
  Duration _now = Duration.zero;

  bool _quiet = false;
  bool _pointerInside = false;
  int _serial = 0;

  CompanionMood get mood => _mood;

  /// Changes each time the visible mood actually changes. Renderers can key
  /// one-shot animations off this instead of watching for repeated events.
  int get reactionSerial => _serial;

  CompanionMoodConfig get config => _config;

  /// Applies new rules. Takes effect immediately and without losing the
  /// standing state (for example, the quiet period).
  void configure(CompanionMoodConfig config) {
    if (config == _config) return;
    _config = config;

    if (!config.animationsEnabled) {
      _enter(CompanionMood.resting, null);
      return;
    }

    // A reaction that is no longer permitted ends now.
    if (_mood.isReaction && !_permits(_mood)) {
      _enter(_standing(), null);
    } else if (_mood == CompanionMood.resting) {
      _enter(_standing(), null);
    }
  }

  /// Delivers an event. Returns true if the visible mood changed.
  bool post(CompanionEvent event, Duration now) {
    _now = now;
    final before = _serial;
    _expire();

    switch (event) {
      case CompanionEvent.quietPeriodStarted:
        _quiet = true;
        if (!_mood.isReaction && _mood != CompanionMood.resting) {
          _enter(_standing(), null);
        }
      case CompanionEvent.quietPeriodEnded:
        _quiet = false;
        if (_mood == CompanionMood.sleepy) _enter(_standing(), null);
      case CompanionEvent.pointerEntered:
        _pointerInside = true;
        _react(CompanionMood.curious);
      case CompanionEvent.pointerExited:
        _pointerInside = false;
      case CompanionEvent.clicked:
        _wakeFromQuiet();
        _react(CompanionMood.attentive);
      case CompanionEvent.breakCompleted:
        _wakeFromQuiet();
        _react(CompanionMood.happy);
      case CompanionEvent.breakReminder:
        _react(CompanionMood.encouraging);
      case CompanionEvent.suddenMotion:
        _react(CompanionMood.surprised);
    }

    return _serial != before;
  }

  /// Moves the clock forward, ending any reaction whose time is up. Returns
  /// true if the visible mood changed.
  bool advance(Duration now) {
    _now = now;
    final before = _serial;
    _expire();
    return _serial != before;
  }

  /// Drops all transient state, e.g. after the machine's host was suspended
  /// and the clock jumped. Standing configuration is kept.
  void reconcile(Duration now) {
    _now = now;
    _pointerInside = false;
    _reactionEndsAt = null;
    _enter(_standing(), null);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  CompanionMood _standing() {
    if (!_config.animationsEnabled) return CompanionMood.resting;
    return _quiet ? CompanionMood.sleepy : CompanionMood.idle;
  }

  bool _permits(CompanionMood mood) {
    if (!_config.animationsEnabled) return false;
    switch (mood) {
      case CompanionMood.curious:
        return _config.interactionsEnabled;
      case CompanionMood.attentive:
        return _config.interactionsEnabled;
      case CompanionMood.happy:
      case CompanionMood.encouraging:
      case CompanionMood.surprised:
        return _config.reactionsEnabled;
      case CompanionMood.idle:
      case CompanionMood.sleepy:
      case CompanionMood.resting:
        return true;
    }
  }

  void _wakeFromQuiet() {
    _quiet = false;
    if (_mood == CompanionMood.sleepy) _enter(CompanionMood.idle, null);
  }

  void _react(CompanionMood candidate) {
    if (!_permits(candidate)) return;
    if (candidate.priority < _mood.priority) return;

    if (candidate == _mood) {
      // Already showing: keep the animation going rather than restarting it.
      // Only a pointer that is still near keeps curiosity alive.
      if (candidate == CompanionMood.curious) {
        _reactionEndsAt = _now + candidate.duration!;
      }
      return;
    }

    _enter(candidate, _now + candidate.duration!);
  }

  void _expire() {
    final end = _reactionEndsAt;
    if (end == null || _now < end) return;
    _reactionEndsAt = null;

    // Linger on curiosity only while the pointer is still near.
    if (_mood == CompanionMood.curious && _pointerInside) {
      _reactionEndsAt = _now + CompanionMood.curious.duration!;
      return;
    }
    _enter(_standing(), null);
  }

  void _enter(CompanionMood mood, Duration? endsAt) {
    _reactionEndsAt = endsAt;
    if (_mood == mood) return;
    _mood = mood;
    _serial++;
  }
}
