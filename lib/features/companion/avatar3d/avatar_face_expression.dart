import 'dart:math' as math;

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';

/// Turns a feeling into a face.
///
/// The companion has no speech bubble and no caption: whatever it feels has to
/// be legible from the shape of its eyes and mouth alone. Each expression below
/// is a set of multipliers against the face the illustrator authored, so a
/// squint on a wide-eyed species still looks like that species squinting rather
/// than like a different animal.
///
/// Every value is scaled by intensity, so a faint feeling is a hint and a
/// strong one is unmistakable — and the resting face is always what a zero
/// intensity returns.

/// How a face changes for one emotion, at full strength.
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

  /// Taller eyes read as surprise or delight; shorter as a squint or sleep.
  final double eyeHeight;
  final double eyeWidth;
  final double eyeGap;
  final double eyeRoundness;

  /// Degrees the outer corner of each eye rotates. Positive droops the outside
  /// downward, which is most of what makes a face read as sad.
  final double outerTilt;

  /// How the mouth is shaped, or null to leave it as authored.
  final _Mouth? mouth;

  /// Eye highlights, the single cheapest way to make a face look alive.
  final _Highlight? highlight;
}

class _Mouth {
  const _Mouth({
    required this.enabled,
    this.curve = 0,
    this.width = 1.0,
    this.height = 1.0,
    this.shape,
  });

  final bool enabled;

  /// `ellipse` for an open mouth, null to keep the authored shape.
  final String? shape;

  /// -100..100. Positive smiles, negative frowns.
  final double curve;
  final double width;
  final double height;
}

class _Highlight {
  const _Highlight({required this.enabled, this.size = 1.0});

  final bool enabled;
  final double size;
}

const Map<PetEmotion, _Expression> _expressions = <PetEmotion, _Expression>{
  // The resting face, barely touched.
  PetEmotion.content: _Expression(
    eyeHeight: 0.94,
    mouth: _Mouth(enabled: true, curve: 22, width: 0.7, height: 0.8),
    highlight: _Highlight(enabled: true, size: 0.9),
  ),

  // A smiling squint: eyes flatten and widen, which is what a genuine smile
  // does to a face and what keeps this from looking like a stare.
  PetEmotion.happy: _Expression(
    eyeHeight: 0.42,
    eyeWidth: 1.25,
    eyeRoundness: 1.2,
    outerTilt: -7,
    mouth: _Mouth(enabled: true, curve: 62, width: 1.0, height: 1.0),
    highlight: _Highlight(enabled: false),
  ),

  // Bright, a little wider eyes and a bigger smile. Kept modest: eyes stretched
  // into tall slits and an open mouth read as alarm, not delight, and the open
  // mouth looked like an oversized nose.
  PetEmotion.excited: _Expression(
    eyeHeight: 1.18,
    eyeWidth: 1.08,
    eyeGap: 0.97,
    eyeRoundness: 1.15,
    mouth: _Mouth(enabled: true, curve: 70, width: 0.95, height: 1.1),
    highlight: _Highlight(enabled: true, size: 1.4),
  ),

  // One raised, slightly narrowed look — attention without alarm.
  PetEmotion.curious: _Expression(
    eyeHeight: 1.12,
    eyeWidth: 0.96,
    outerTilt: -4,
    mouth: _Mouth(enabled: true, curve: 12, width: 0.55, height: 0.7),
    highlight: _Highlight(enabled: true, size: 1.2),
  ),

  // The warmest face: closed, upturned eyes.
  PetEmotion.affectionate: _Expression(
    eyeHeight: 0.3,
    eyeWidth: 1.3,
    eyeRoundness: 1.3,
    outerTilt: -12,
    mouth: _Mouth(enabled: true, curve: 75, width: 0.9, height: 1.1),
    highlight: _Highlight(enabled: false),
  ),

  // Drooping outer corners and a small downturned mouth. Wistful rather than
  // miserable — this is a pet waiting, not a pet in distress.
  PetEmotion.lonely: _Expression(
    eyeHeight: 1.08,
    eyeWidth: 0.95,
    eyeGap: 1.05,
    outerTilt: 11,
    mouth: _Mouth(enabled: true, curve: -34, width: 0.6, height: 0.7),
    highlight: _Highlight(enabled: true, size: 1.1),
  ),

  // Heavy lids, a flat mouth.
  PetEmotion.weary: _Expression(
    eyeHeight: 0.55,
    eyeWidth: 1.02,
    outerTilt: 7,
    mouth: _Mouth(enabled: true, curve: -8, width: 0.55, height: 0.6),
    highlight: _Highlight(enabled: false),
  ),

  // Shut. The blink channel closes them the rest of the way.
  PetEmotion.sleepy: _Expression(
    eyeHeight: 0.16,
    eyeWidth: 1.1,
    eyeRoundness: 1.4,
    outerTilt: 4,
    mouth: _Mouth(enabled: false),
    highlight: _Highlight(enabled: false),
  ),

  // Eyes open wide and round, a small "o" of a mouth.
  PetEmotion.startled: _Expression(
    eyeHeight: 1.3,
    eyeWidth: 1.12,
    eyeGap: 0.95,
    eyeRoundness: 1.5,
    mouth: _Mouth(
      enabled: true,
      shape: 'ellipse',
      curve: -10,
      width: 0.4,
      height: 1.1,
    ),
    highlight: _Highlight(enabled: true, size: 1.5),
  ),
};

/// Applies [state] to the authored [face].
///
/// [blink] closes the lids on top of whatever the emotion is doing, so a happy
/// pet still blinks happily.
AvatarFaceStyle expressFace(
  AvatarFaceStyle face,
  PetEmotionState state, {
  double blink = 0,
}) {
  final expression = _expressions[state.emotion];
  if (expression == null) return face;

  // Everything is interpolated from the resting face, so intensity 0 is
  // exactly what the illustrator drew.
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
    // The tilt mirrors, so both outer corners move the same way — rotating
    // both eyes the same direction reads as a head tilt, not an expression.
    leftEyeRotation: face.leftEyeRotation + expression.outerTilt * t,
    rightEyeRotation: face.rightEyeRotation - expression.outerTilt * t,
    mouthEnabled: mouth == null ? face.mouthEnabled : mouth.enabled,
    // The shape only swaps once the feeling is strong enough to warrant it;
    // a faintly surprised pet should not gape.
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
    highlightEnabled: highlight == null
        ? face.highlightEnabled
        : highlight.enabled,
    highlightSize: highlight == null
        ? face.highlightSize
        : face.highlightSize * blend(highlight.size),
  );
}
