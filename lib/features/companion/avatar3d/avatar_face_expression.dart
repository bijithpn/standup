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
    this.rotation = 0,
    this.shape,
  });

  final bool enabled;

  /// `ellipse` for a round "o", `open` for a grin with the mouth open, null to
  /// keep the authored stroke.
  final String? shape;

  /// -100..100. Positive smiles, negative frowns.
  final double curve;
  final double width;
  final double height;

  /// Degrees the whole mouth is turned, for a lopsided grin.
  final double rotation;
}

class _Highlight {
  const _Highlight({required this.enabled, this.size = 1.0});

  final bool enabled;
  final double size;
}

const Map<PetEmotion, _Expression> _expressions = <PetEmotion, _Expression>{
  // Resting: round open eyes, a small calm smile.
  PetEmotion.content: _Expression(
    mouth: _Mouth(enabled: true, curve: 45, width: 0.9, height: 0.8),
    highlight: _Highlight(enabled: true, size: 1.0),
  ),

  // Pleased: eyes crinkle into upturned arcs over a wide, clean smile.
  PetEmotion.happy: _Expression(
    eyeHeight: 0.34,
    eyeWidth: 1.4,
    eyeRoundness: 1.3,
    outerTilt: -14,
    mouth: _Mouth(enabled: true, curve: 90, width: 1.5, height: 0.9),
    highlight: _Highlight(enabled: false),
  ),

  // Bright and bouncy: big round eyes full of sparkle, a wide open grin.
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

  // Interested: bigger, rounder eyes with a bright catchlight, a tiny "o".
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

  // The warmest face: huge shiny eyes and a soft smile with rosy cheeks.
  PetEmotion.affectionate: _Expression(
    eyeHeight: 1.28,
    eyeWidth: 1.28,
    eyeGap: 1.05,
    eyeRoundness: 1.7,
    mouth: _Mouth(enabled: true, curve: 75, width: 1.1, height: 0.9),
    highlight: _Highlight(enabled: true, size: 2.2),
  ),

  // Drooping outer corners and a small downturned mouth. Wistful, not
  // miserable.
  PetEmotion.lonely: _Expression(
    eyeHeight: 1.1,
    eyeGap: 1.08,
    eyeRoundness: 1.4,
    outerTilt: 16,
    mouth: _Mouth(enabled: true, curve: -70, width: 0.85, height: 0.8),
    highlight: _Highlight(enabled: true, size: 1.6),
  ),

  // Heavy lids, a flat mouth.
  PetEmotion.weary: _Expression(
    eyeHeight: 0.5,
    eyeWidth: 1.05,
    outerTilt: 9,
    mouth: _Mouth(enabled: true, curve: -15, width: 0.7, height: 0.7),
    highlight: _Highlight(enabled: false),
  ),

  // Shut. The blink channel closes them the rest of the way.
  PetEmotion.sleepy: _Expression(
    eyeHeight: 0.14,
    eyeWidth: 1.2,
    eyeRoundness: 1.4,
    outerTilt: 6,
    mouth: _Mouth(enabled: false),
    highlight: _Highlight(enabled: false),
  ),

  // Wide round eyes, a round "o" of a mouth.
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

  // Cheeky: one corner of the grin higher than the other, eyes a touch
  // narrowed and tilted, as if it has just thought of something.
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

  // Laughing out loud: eyes shut in happy arcs, mouth wide open.
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

/// How much rosy cheek an emotion shows, 0..1. Blush is what makes a happy
/// face read as affection rather than as a grin.
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
