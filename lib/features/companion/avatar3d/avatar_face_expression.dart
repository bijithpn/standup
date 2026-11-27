import 'dart:math' as math;

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';

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
    eyeHeight: 0.42,
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

  PetEmotion.dizzy: _Expression(
    eyeHeight: 1.0,
    eyeWidth: 1.15,
    eyeGap: 1.04,
    eyeRoundness: 1.7,
    outerTilt: 6,
    mouth: _Mouth(
      enabled: true,
      shape: 'ellipse',
      curve: -20,
      width: 0.6,
      height: 0.9,
      rotation: 8,
    ),
    highlight: _Highlight(enabled: false),
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

/// Brow, cheek, ear, beak and head-nod channels layered on the eye/mouth expression; all zero is a neutral face.
class FaceRig {
  const FaceRig({
    this.browAngle = 0,
    this.browLift = 0,
    this.browAsym = 0,
    this.cheek = 0,
    this.earDroop = 0,
    this.earRot = 0,
    this.beak = 0,
    this.nose = 0,
    this.pitch = 0,
    this.nod = 0,
  });

  /// Degrees; positive raises the inner brow ends (worried), negative lowers them (stern).
  final double browAngle;

  /// In eye widths; positive raises both brows.
  final double browLift;

  /// Extra lift on the right brow (and a smaller dip on the left).
  final double browAsym;

  final double cheek;

  /// Positive droops ears/crests outward and down, negative perks them up.
  final double earDroop;

  /// Degrees added to every ear, used for secondary lag.
  final double earRot;

  final double beak;

  /// Nose twitch amplitude at rest; the view animates it.
  final double nose;

  /// Head nod offset in radians (positive looks down) and an animated nod amplitude.
  final double pitch;
  final double nod;

  static const FaceRig neutral = FaceRig();

  FaceRig copyWith({double? earRot, double? nose, double? pitch}) => FaceRig(
    browAngle: browAngle,
    browLift: browLift,
    browAsym: browAsym,
    cheek: cheek,
    earDroop: earDroop,
    earRot: earRot ?? this.earRot,
    beak: beak,
    nose: nose ?? this.nose,
    pitch: pitch ?? this.pitch,
    nod: nod,
  );

  FaceRig lerpTo(FaceRig o, double t) {
    double m(double a, double b) => a + (b - a) * t;
    return FaceRig(
      browAngle: m(browAngle, o.browAngle),
      browLift: m(browLift, o.browLift),
      browAsym: m(browAsym, o.browAsym),
      cheek: m(cheek, o.cheek),
      earDroop: m(earDroop, o.earDroop),
      earRot: m(earRot, o.earRot),
      beak: m(beak, o.beak),
      nose: m(nose, o.nose),
      pitch: m(pitch, o.pitch),
      nod: m(nod, o.nod),
    );
  }

  bool isCloseTo(FaceRig o, {double epsilon = 0.01}) =>
      (browAngle - o.browAngle).abs() < epsilon * 20 &&
      (browLift - o.browLift).abs() < epsilon &&
      (browAsym - o.browAsym).abs() < epsilon &&
      (cheek - o.cheek).abs() < epsilon &&
      (earDroop - o.earDroop).abs() < epsilon &&
      (earRot - o.earRot).abs() < epsilon * 30 &&
      (beak - o.beak).abs() < epsilon &&
      (nose - o.nose).abs() < epsilon &&
      (pitch - o.pitch).abs() < epsilon &&
      (nod - o.nod).abs() < epsilon;
}

const Map<PetEmotion, FaceRig> _rigs = <PetEmotion, FaceRig>{
  PetEmotion.content: FaceRig(browLift: 0.05, cheek: 0.2),
  PetEmotion.happy: FaceRig(
    browLift: 0.3,
    cheek: 0.8,
    earDroop: -0.3,
    beak: 0.25,
  ),
  PetEmotion.excited: FaceRig(
    browLift: 0.8,
    cheek: 0.3,
    earDroop: -0.9,
    beak: 0.6,
    nose: 0.5,
  ),
  PetEmotion.curious: FaceRig(
    browLift: 0.25,
    browAsym: 0.8,
    earDroop: -0.6,
    nose: 1,
  ),
  PetEmotion.affectionate: FaceRig(
    browAngle: 10,
    browLift: 0.15,
    cheek: 0.6,
    earDroop: 0.15,
    beak: 0.1,
  ),
  PetEmotion.lonely: FaceRig(
    browAngle: 24,
    browLift: -0.05,
    earDroop: 1,
    pitch: 0.16,
  ),
  PetEmotion.weary: FaceRig(
    browAngle: 6,
    browLift: -0.4,
    earDroop: 0.6,
    pitch: 0.08,
  ),
  PetEmotion.sleepy: FaceRig(
    browLift: -0.55,
    earDroop: 0.7,
    pitch: 0.1,
    nod: 1,
  ),
  PetEmotion.startled: FaceRig(
    browAngle: 6,
    browLift: 1,
    earDroop: -1,
    beak: 0.75,
    nose: 0.4,
  ),
  PetEmotion.playful: FaceRig(
    browLift: 0.4,
    browAsym: 0.5,
    cheek: 0.5,
    earDroop: -0.5,
    beak: 0.3,
  ),
  PetEmotion.dizzy: FaceRig(
    browAngle: 14,
    browAsym: -0.6,
    earDroop: 0.3,
    beak: 0.2,
  ),
  PetEmotion.laughing: FaceRig(
    browLift: 0.5,
    cheek: 1,
    earDroop: -0.2,
    beak: 1,
  ),
};

/// Target rig for the emotion; every channel scales with intensity.
FaceRig rigFor(PetEmotionState state) => FaceRig.neutral.lerpTo(
  _rigs[state.emotion] ?? FaceRig.neutral,
  state.intensity.clamp(0.0, 1.0),
);

final RegExp _earParts = RegExp(r'(^|-)(ear|crest|whisker)');

/// Droops/perks and swings ears, crests and whiskers; the left/right sign comes from the part's x.
List<AvatarPart> poseParts(List<AvatarPart> parts, FaceRig rig) {
  if (rig.isCloseTo(FaceRig.neutral)) return parts;
  return [for (final p in parts) _posePart(p, parts, rig)];
}

AvatarPart _posePart(AvatarPart p, List<AvatarPart> parts, FaceRig rig) {
  if (_earParts.hasMatch(p.id)) {
    final sign = p.x.sign;
    AvatarPart root = p;
    for (final candidate in parts) {
      if (candidate.id.startsWith('ear-') && candidate.x.sign == sign) {
        root = candidate;
        break;
      }
    }
    // Rotate the whole ear assembly around its embedded root, including lining.
    final pivotX = root.x * .85;
    final pivotY = root.y + root.scaleY * 90;
    final degrees = rig.earDroop * 12 * sign + rig.earRot.clamp(-8.0, 8.0);
    final angle = degrees * math.pi / 180;
    final dx = p.x - pivotX, dy = p.y - pivotY;
    return p.copyWith(
      x: pivotX + dx * math.cos(angle) - dy * math.sin(angle),
      y: pivotY + dx * math.sin(angle) + dy * math.cos(angle),
      rotationZ: p.rotationZ + degrees,
    );
  }
  if (p.id == 'beak-lower' || p.id == 'bill-lower') {
    return p.copyWith(
      y: p.y + rig.beak.clamp(0.0, .8) * 9,
      rotationX: p.rotationX + rig.beak.clamp(0.0, 1.0) * 9,
    );
  }
  if (p.hasFace && p.muzzleProjection > 0) {
    return p.copyWith(
      muzzleProjection: p.muzzleProjection * (1 + rig.cheek * .045),
      muzzleWidth: p.muzzleWidth * (1 + rig.cheek * .035),
    );
  }
  if (p.id == 'nose') return p.copyWith(y: p.y - rig.nose * 1.2);
  return p;
}

/// Single owner for expression and behavior channels, used by the live widget
/// and validation renderer. Tracking has priority over expression secondary motion.
FaceRig composeFaceRig(
  String preset,
  FaceRig emotion,
  PetBehaviorSnapshot snapshot, {
  double earLag = 0,
  double nosePulse = 0,
}) => FaceRig(
  cheek: emotion.cheek + snapshot.cheekLift * .2,
  browAsym: emotion.browAsym,
  earDroop: (emotion.earDroop - snapshot.earPose * .3).clamp(-1.0, 1.0),
  earRot: earLag * 10,
  beak: math.max(emotion.beak, snapshot.beakOpen),
  nose:
      snapshot.noseTwitch +
      ({'rabbit', 'hamster', 'chinchilla', 'guinea-pig'}.contains(preset)
          ? emotion.nose * nosePulse
          : 0),
  pitch: emotion.pitch,
  nod: emotion.nod,
);

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
    height:
        face.height *
        blend(expression.eyeHeight) *
        (1 - 0.18 * (_rigs[state.emotion]?.cheek ?? 0) * t) *
        lidsOpen,
    width: face.width * blend(expression.eyeWidth),
    gap: face.gap * blend(expression.eyeGap),
    eyeRoundness: math.min(
      100,
      face.eyeRoundness * blend(expression.eyeRoundness),
    ),

    leftEyeRotation: face.leftEyeRotation + expression.outerTilt * t,
    rightEyeRotation: face.rightEyeRotation - expression.outerTilt * t,
    mouthEnabled: face.mouthEnabled && (mouth?.enabled ?? true),

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
    highlightEnabled: face.highlightEnabled && (highlight?.enabled ?? true),
    highlightSize: highlight == null
        ? face.highlightSize
        : face.highlightSize * blend(highlight.size),
  );
}
