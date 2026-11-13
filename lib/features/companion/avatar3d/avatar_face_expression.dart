import 'dart:math' as math;

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';

/// Per-emotion multipliers/offsets applied on top of the scene's authored face.
class _Expression {
  const _Expression({
    this.eyeHeight = 1.0,
    this.eyeWidth = 1.0,
    this.eyeGap = 1.0,
    this.eyeRoundness = 1.0,
    this.outerTilt = 0.0,
    this.mouth,
    this.highlight,
  });

  final double eyeHeight;
  final double eyeWidth;
  final double eyeGap;
  final double eyeRoundness;

  final double outerTilt;

  final _Mouth? mouth;

  final _Highlight? highlight;
}

class _Mouth {
  const _Mouth({
    required this.enabled,
    this.curve = 0,
    this.width = 1.0,
    this.height = 1.0,
    this.rotation = 0,
    this.shape,
  });

  final bool enabled;

  final String? shape;

  final double curve;
  final double width;
  final double height;

  final double rotation;
}

class _Highlight {
  const _Highlight({required this.enabled, this.size = 1.0});

  final bool enabled;
  final double size;
}

const Map<PetEmotion, _Expression> _expressions = <PetEmotion, _Expression>{
  PetEmotion.content: _Expression(
    mouth: _Mouth(enabled: true, curve: 45, width: 0.9, height: 0.8),
    highlight: _Highlight(enabled: true, size: 1.0),
  ),

  PetEmotion.happy: _Expression(
    eyeHeight: 0.34,
    eyeWidth: 1.4,
    eyeRoundness: 1.3,
    outerTilt: -14,
    mouth: _Mouth(enabled: true, curve: 90, width: 1.5, height: 0.9),
    highlight: _Highlight(enabled: false),
  ),

  PetEmotion.excited: _Expression(
    eyeHeight: 1.28,
    eyeWidth: 1.22,
    eyeGap: 0.96,
    eyeRoundness: 1.6,
    mouth: _Mouth(
      enabled: true,
      shape: 'open',
      curve: 55,
      width: 1.3,
      height: 1.9,
    ),
    highlight: _Highlight(enabled: true, size: 1.9),
  ),

  PetEmotion.curious: _Expression(
    eyeHeight: 1.2,
    eyeWidth: 1.1,
    eyeRoundness: 1.4,
    outerTilt: -3,
    mouth: _Mouth(
      enabled: true,
      shape: 'ellipse',
      curve: 0,
      width: 0.4,
      height: 0.9,
    ),
    highlight: _Highlight(enabled: true, size: 1.7),
  ),

  PetEmotion.affectionate: _Expression(
    eyeHeight: 1.28,
    eyeWidth: 1.28,
    eyeGap: 1.05,
    eyeRoundness: 1.7,
    mouth: _Mouth(enabled: true, curve: 75, width: 1.1, height: 0.9),
    highlight: _Highlight(enabled: true, size: 2.2),
  ),

  PetEmotion.lonely: _Expression(
    eyeHeight: 1.1,
    eyeGap: 1.08,
    eyeRoundness: 1.4,
    outerTilt: 16,
    mouth: _Mouth(enabled: true, curve: -70, width: 0.85, height: 0.8),
    highlight: _Highlight(enabled: true, size: 1.6),
  ),

  PetEmotion.weary: _Expression(
    eyeHeight: 0.5,
    eyeWidth: 1.05,
    outerTilt: 9,
    mouth: _Mouth(enabled: true, curve: -15, width: 0.7, height: 0.7),
    highlight: _Highlight(enabled: false),
  ),

  PetEmotion.sleepy: _Expression(
    eyeHeight: 0.14,
    eyeWidth: 1.2,
    eyeRoundness: 1.4,
    outerTilt: 6,
    mouth: _Mouth(enabled: false),
    highlight: _Highlight(enabled: false),
  ),

  PetEmotion.startled: _Expression(
    eyeHeight: 1.45,
    eyeWidth: 1.2,
    eyeGap: 0.95,
    eyeRoundness: 1.7,
    mouth: _Mouth(
      enabled: true,
      shape: 'ellipse',
      curve: 0,
      width: 0.55,
      height: 1.5,
    ),
    highlight: _Highlight(enabled: true, size: 1.4),
  ),

  PetEmotion.playful: _Expression(
    eyeHeight: 0.92,
    eyeWidth: 1.1,
    eyeRoundness: 1.4,
    outerTilt: -10,
    mouth: _Mouth(
      enabled: true,
      curve: 80,
      width: 1.25,
      height: 0.95,
      rotation: -9,
    ),
    highlight: _Highlight(enabled: true, size: 1.8),
  ),

  PetEmotion.laughing: _Expression(
    eyeHeight: 0.22,
    eyeWidth: 1.5,
    eyeRoundness: 1.3,
    outerTilt: -16,
    mouth: _Mouth(
      enabled: true,
      shape: 'open',
      curve: 70,
      width: 1.45,
      height: 2.1,
    ),
    highlight: _Highlight(enabled: false),
  ),
};

/// Blush opacity derived from emotion intensity.
double blushFor(PetEmotionState state) {
  final base = switch (state.emotion) {
    PetEmotion.affectionate => 1.0,
    PetEmotion.happy => 0.8,
    PetEmotion.excited => 0.55,
    PetEmotion.playful => 0.5,
    PetEmotion.laughing => 0.9,
    PetEmotion.content => 0.2,
    PetEmotion.curious => 0.15,
    _ => 0.0,
  };
  return base * state.intensity.clamp(0.0, 1.0);
}

/// Maps a PetEmotionState to the face style to show; blending between emotions happens in Avatar3DView.
AvatarFaceStyle expressFace(
  AvatarFaceStyle face,
  PetEmotionState state, {
  double blink = 0,
}) {
  final expression = _expressions[state.emotion];
  if (expression == null) return face;

  final t = state.intensity.clamp(0.0, 1.0);
  double blend(double target) => 1 + (target - 1) * t;

  final lidsOpen = (1 - blink).clamp(0.04, 1.0);

  final mouth = expression.mouth;
  final highlight = expression.highlight;

  return face.copyWithExpression(
    height: face.height * blend(expression.eyeHeight) * lidsOpen,
    width: face.width * blend(expression.eyeWidth),
    gap: face.gap * blend(expression.eyeGap),
    eyeRoundness: math.min(
      100,
      face.eyeRoundness * blend(expression.eyeRoundness),
    ),

    leftEyeRotation: face.leftEyeRotation + expression.outerTilt * t,
    rightEyeRotation: face.rightEyeRotation - expression.outerTilt * t,
    mouthEnabled: mouth == null ? face.mouthEnabled : mouth.enabled,

    mouthShape: mouth?.shape != null && t > 0.5 ? mouth!.shape : null,
    mouthCurve: mouth == null
        ? face.mouthCurve
        : face.mouthCurve + (mouth.curve - face.mouthCurve) * t,
    mouthWidth: mouth == null
        ? face.mouthWidth
        : face.mouthWidth * blend(mouth.width),
    mouthHeight: mouth == null
        ? face.mouthHeight
        : face.mouthHeight * blend(mouth.height),
    mouthRotation: mouth == null
        ? face.mouthRotation
        : face.mouthRotation + mouth.rotation * t,
    highlightEnabled: highlight == null
        ? face.highlightEnabled
        : highlight.enabled,
    highlightSize: highlight == null
        ? face.highlightSize
        : face.highlightSize * blend(highlight.size),
  );
}
