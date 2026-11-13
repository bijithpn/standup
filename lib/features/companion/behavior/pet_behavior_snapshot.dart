import 'dart:ui' show Offset;

import 'package:breakmate/features/companion/behavior/companion_mood_machine.dart';
import 'package:breakmate/features/companion/behavior/gaze_sector.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';

/// Coarse activity label derived from the engine state.
enum PetActivity {
  sleeping,

  drowsy,

  idle,

  curious,

  watching,

  playful,

  startled,

  delighted,
}

/// Immutable per-frame pose/emotion output of PetBehaviorEngine consumed by the avatar views.
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
    this.emotion = PetEmotionState.neutral,
    this.gazeDirection = GazeDirection.center,
    this.mood = CompanionMood.idle,
  });

  final Offset gaze;

  final Offset headTurn;

  final Offset bodyLean;

  final double blink;

  final double breath;

  final double bounce;

  final double squash;

  final double tilt;

  final double arousal;

  final double attention;

  final PetActivity activity;

  final PetEmotionState emotion;

  final GazeDirection gazeDirection;

  final CompanionMood mood;

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
    PetEmotionState? emotion,
    GazeDirection? gazeDirection,
    CompanionMood? mood,
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
      emotion: emotion ?? this.emotion,
      gazeDirection: gazeDirection ?? this.gazeDirection,
      mood: mood ?? this.mood,
    );
  }

  @override
  String toString() =>
      'PetBehaviorSnapshot(${activity.name}, '
      'gaze: ${gaze.dx.toStringAsFixed(2)},${gaze.dy.toStringAsFixed(2)}, '
      'arousal: ${arousal.toStringAsFixed(2)})';
}
