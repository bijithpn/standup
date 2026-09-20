import 'dart:ui' show Offset;

/// What the pet is doing right now, at the coarse level a viewer would name.
enum PetActivity {
  /// Eyes shut, breathing deep and slow.
  sleeping,

  /// Lids heavy, losing interest, one nudge from sleep.
  drowsy,

  /// Awake and settled, looking around of its own accord.
  idle,

  /// Something caught its eye and it is deciding whether to care.
  curious,

  /// Locked onto the cursor and following it.
  watching,

  /// Wound up — quick movements, exaggerated follow.
  playful,

  /// Just got a fright.
  startled,

  /// Being petted.
  delighted,
}

/// One frame of pet motion.
///
/// Everything is a plain number in a normalised range so the same snapshot can
/// drive the illustrated avatar, the generative blob, or anything added later.
class PetBehaviorSnapshot {
  const PetBehaviorSnapshot({
    this.gaze = Offset.zero,
    this.headTurn = Offset.zero,
    this.bodyLean = Offset.zero,
    this.blink = 0.0,
    this.breath = 0.0,
    this.bounce = 0.0,
    this.squash = 1.0,
    this.tilt = 0.0,
    this.arousal = 0.3,
    this.attention = 0.0,
    this.activity = PetActivity.idle,
  });

  /// Where the eyes point, each axis -1..1. Positive is right and down.
  final Offset gaze;

  /// Where the head points, -1..1. Lags [gaze]: a real animal's eyes arrive
  /// first and the head catches up.
  final Offset headTurn;

  /// Whole-body lean, -1..1. Lags [headTurn] again, and much more heavily.
  final Offset bodyLean;

  /// Lid closure, 0 fully open .. 1 fully shut.
  final double blink;

  /// Breathing phase, -1..1.
  final double breath;

  /// Vertical offset in logical pixels, negative is up.
  final double bounce;

  /// Uniform scale, 1.0 at rest. Pairs with [bounce] for squash and stretch.
  final double squash;

  /// Head roll in radians.
  final double tilt;

  /// How wound up the pet is, 0..1. Drives breath rate and motion scale.
  final double arousal;

  /// How locked onto the cursor it is, 0..1.
  final double attention;

  final PetActivity activity;

  /// True when the pet is alert enough to react to things.
  bool get isAwake =>
      activity != PetActivity.sleeping && activity != PetActivity.drowsy;

  PetBehaviorSnapshot copyWith({
    Offset? gaze,
    Offset? headTurn,
    Offset? bodyLean,
    double? blink,
    double? breath,
    double? bounce,
    double? squash,
    double? tilt,
    double? arousal,
    double? attention,
    PetActivity? activity,
  }) {
    return PetBehaviorSnapshot(
      gaze: gaze ?? this.gaze,
      headTurn: headTurn ?? this.headTurn,
      bodyLean: bodyLean ?? this.bodyLean,
      blink: blink ?? this.blink,
      breath: breath ?? this.breath,
      bounce: bounce ?? this.bounce,
      squash: squash ?? this.squash,
      tilt: tilt ?? this.tilt,
      arousal: arousal ?? this.arousal,
      attention: attention ?? this.attention,
      activity: activity ?? this.activity,
    );
  }

  @override
  String toString() => 'PetBehaviorSnapshot(${activity.name}, '
      'gaze: ${gaze.dx.toStringAsFixed(2)},${gaze.dy.toStringAsFixed(2)}, '
      'arousal: ${arousal.toStringAsFixed(2)})';
}
