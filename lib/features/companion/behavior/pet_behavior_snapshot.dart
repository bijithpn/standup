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

  dizzy,
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
    this.browRaise = 0.0,
    this.cheekLift = 0.0,
    this.earPose = 0.0,
    this.beakOpen = 0.0,
    this.noseTwitch = 0.0,
    this.gazeX = 0.0,
    this.gazeY = 0.0,
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

  /// -1 lowered/worried .. 1 raised.
  final double browRaise;

  /// 0..1 smile-driven cheek lift.
  final double cheekLift;

  /// -1 drooped .. 1 perked, including brief twitches.
  final double earPose;

  /// 0..1 beak/mouth opening beyond the emotion face.
  final double beakOpen;

  /// 0..1 nose twitch pulse.
  final double noseTwitch;

  /// Same as gaze.dx / gaze.dy, -1..1.
  final double gazeX;
  final double gazeY;

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
    double? browRaise,
    double? cheekLift,
    double? earPose,
    double? beakOpen,
    double? noseTwitch,
    double? gazeX,
    double? gazeY,
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
      browRaise: browRaise ?? this.browRaise,
      cheekLift: cheekLift ?? this.cheekLift,
      earPose: earPose ?? this.earPose,
      beakOpen: beakOpen ?? this.beakOpen,
      noseTwitch: noseTwitch ?? this.noseTwitch,
      gazeX: gazeX ?? this.gazeX,
      gazeY: gazeY ?? this.gazeY,
    );
  }

  @override
  String toString() =>
      'PetBehaviorSnapshot(${activity.name}, '
      'gaze: ${gaze.dx.toStringAsFixed(2)},${gaze.dy.toStringAsFixed(2)}, '
      'arousal: ${arousal.toStringAsFixed(2)})';
}
