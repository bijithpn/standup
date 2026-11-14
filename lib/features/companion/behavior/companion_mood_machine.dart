import 'package:breakmate/features/companion/behavior/pet_emotion.dart';

/// Companion's high-level mood; higher priority wins, and reaction moods (with a duration) expire back to the standing mood.
enum CompanionMood {
  idle(0),

  sleepy(10),

  curious(20),

  attentive(30),

  encouraging(40),

  happy(50),

  surprised(60),

  resting(100);

  const CompanionMood(this.priority);

  final int priority;

  Duration? get duration => switch (this) {
    CompanionMood.curious => const Duration(milliseconds: 2200),
    CompanionMood.attentive => const Duration(milliseconds: 1400),
    CompanionMood.encouraging => const Duration(milliseconds: 4000),
    CompanionMood.happy => const Duration(milliseconds: 3600),
    CompanionMood.surprised => const Duration(milliseconds: 900),
    CompanionMood.idle || CompanionMood.sleepy || CompanionMood.resting => null,
  };

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

  bool get isReaction => duration != null;
}

/// External triggers fed to CompanionMoodMachine.post.
enum CompanionEvent {
  pointerEntered,

  pointerExited,

  clicked,

  breakCompleted,

  breakReminder,

  suddenMotion,

  quietPeriodStarted,

  quietPeriodEnded,
}

class CompanionMoodConfig {
  const CompanionMoodConfig({
    this.animationsEnabled = true,
    this.reactionsEnabled = true,
    this.interactionsEnabled = true,
  });

  final bool animationsEnabled;

  final bool reactionsEnabled;

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

/// Pure state machine (no timers): the caller supplies a monotonic clock via post/advance, and reactions are gated by CompanionMoodConfig.
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

  int get reactionSerial => _serial;

  CompanionMoodConfig get config => _config;

  void configure(CompanionMoodConfig config) {
    if (config == _config) return;
    _config = config;

    if (!config.animationsEnabled) {
      _enter(CompanionMood.resting, null);
      return;
    }

    if (_mood.isReaction && !_permits(_mood)) {
      _enter(_standing(), null);
    } else if (_mood == CompanionMood.resting) {
      _enter(_standing(), null);
    }
  }

  /// Applies an event; returns true if the mood changed (reactionSerial is bumped for each new reaction).
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

  bool advance(Duration now) {
    _now = now;
    final before = _serial;
    _expire();
    return _serial != before;
  }

  /// Resets to the standing mood after a suspend/resume, dropping any stale reaction or hover state.
  void reconcile(Duration now) {
    _now = now;
    _pointerInside = false;
    _reactionEndsAt = null;
    _enter(_standing(), null);
  }

  /// Resting-state mood: resting if animations are off, sleepy in a quiet period, otherwise idle.
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
