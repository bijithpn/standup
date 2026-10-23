import 'dart:math' as math;

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';

/// Eyes, nose and mouth sized for each animal's own body.
///
/// Every scene ships with the same default face, so a bear, a fox and a
/// hamster all wore identical tall slits and the same mouth. These are the
/// proportions each one should have instead: small dots for the bear, narrow
/// slanted eyes for the fox, huge round ones for the chinchilla and the owl.
/// Expressions then reshape whatever is set here, so the species stays itself
/// when it smiles.
///
/// Eye width/height are in the face's own units (the default is 22 × 64, a
/// tall pill); the gap is the distance between the eyes.
class _Face {
  const _Face({
    required this.w,
    required this.h,
    required this.gap,
    this.tilt = 0,
    this.nose,
    this.mouthW = 26,
    this.mouthH = 8,
    this.curve = 50,
    this.noseY = 28,
  });

  final double w;
  final double h;
  final double gap;

  /// Degrees the outer eye corners tilt up (negative) or droop (positive).
  final double tilt;

  /// Nose width and height, or null for no nose.
  final (double, double)? nose;
  final double noseY;
  final double mouthW;
  final double mouthH;
  final double curve;
}

const Map<String, _Face> _faces = <String, _Face>{
  // Cats: almond eyes tilted up, a tiny nose, a little "w" of a mouth.
  'cat': _Face(
    w: 22,
    h: 40,
    gap: 50,
    tilt: -12,
    nose: (11, 8),
    mouthW: 24,
    curve: 70,
  ),
  'tiger': _Face(w: 18, h: 22, gap: 60, tilt: -8, nose: (18, 12), mouthW: 26),
  'lion': _Face(w: 18, h: 24, gap: 52, tilt: -4, nose: (18, 12), mouthW: 26),
  // Dogs and relatives: round friendly eyes, a big nose, a wide smile.
  'dog': _Face(
    w: 28,
    h: 32,
    gap: 54,
    nose: (22, 15),
    noseY: 32,
    mouthW: 32,
    curve: 60,
  ),
  'fox': _Face(
    w: 22,
    h: 30,
    gap: 58,
    tilt: -20,
    nose: (11, 8),
    noseY: 38,
    mouthW: 22,
    curve: 30,
  ),
  // Bears and chunky friends: small dot eyes set wide.
  'bear': _Face(w: 18, h: 22, gap: 62, nose: (18, 12), noseY: 34, mouthW: 22),
  'otter': _Face(w: 20, h: 24, gap: 54, nose: (20, 13), noseY: 30, mouthW: 22),
  'seal': _Face(w: 22, h: 28, gap: 56, nose: (14, 10), mouthW: 22),
  'monkey': _Face(w: 20, h: 24, gap: 44, mouthW: 26),
  // Small furry things: big glossy round eyes.
  'hamster': _Face(w: 26, h: 30, gap: 64, nose: (9, 7), mouthW: 14, curve: 60),
  'guinea-pig': _Face(w: 20, h: 24, gap: 58, nose: (12, 9), mouthW: 16),
  'chinchilla': _Face(w: 30, h: 34, gap: 52, nose: (9, 7), mouthW: 14),
  'squirrel': _Face(w: 22, h: 30, gap: 46, nose: (8, 6), mouthW: 14),
  'ferret': _Face(w: 16, h: 20, gap: 38, tilt: -6, nose: (9, 7), mouthW: 14),
  'beaver': _Face(w: 16, h: 20, gap: 52),
  'hedgehog': _Face(
    w: 13,
    h: 18,
    gap: 42,
    nose: (15, 11),
    noseY: 34,
    mouthW: 14,
  ),
  'capybara': _Face(
    w: 14,
    h: 14,
    gap: 72,
    nose: (14, 10),
    mouthW: 24,
    curve: 15,
  ),
  // Long-faced: tall soft eyes.
  'rabbit': _Face(w: 18, h: 44, gap: 40, mouthW: 12, mouthH: 6, curve: 80),
  'bun': _Face(w: 14, h: 18, gap: 46, mouthW: 18, curve: 60),
  'deer': _Face(w: 20, h: 38, gap: 46, tilt: -4, nose: (13, 9), mouthW: 16),
  'alpaca': _Face(
    w: 16,
    h: 32,
    gap: 52,
    tilt: -6,
    nose: (9, 7),
    mouthW: 18,
    curve: 40,
  ),
  'sheep': _Face(w: 20, h: 28, gap: 52, nose: (11, 8), mouthW: 18),
  'cow': _Face(w: 22, h: 32, gap: 64, mouthW: 26),
  'pig': _Face(w: 18, h: 26, gap: 74, mouthW: 28),
  // Birds: the beak is the mouth. Eyes only.
  'chick': _Face(w: 18, h: 22, gap: 58),
  'duck': _Face(w: 16, h: 21, gap: 62),
  'goose': _Face(w: 16, h: 21, gap: 54),
  'penguin': _Face(w: 24, h: 30, gap: 52),
  'parrot': _Face(w: 18, h: 22, gap: 44),
  'owl': _Face(w: 36, h: 40, gap: 62, tilt: 4),
  // Weather: simple and happy.
  'cloud': _Face(w: 16, h: 20, gap: 50, mouthW: 18, curve: 85),
  'sun': _Face(w: 16, h: 24, gap: 46, mouthW: 22, curve: 75),
};

const double _minimumEyeScale = 0.75;

/// Species drawn with eyes too small to carry an expression, because a muzzle
/// or cheeks take most of the face. Their eyes are enlarged past the
/// illustrator's size, by this much, so that a smile or a start still shows.
const Map<String, double> _eyeBoost = <String, double>{
  'capybara': 1.4,
  'beaver': 1.35,
  'seal': 1.35,
  'hedgehog': 1.3,
  'bun': 1.3,
  'guinea-pig': 1.15,
  'hamster': 1.15,
  'squirrel': 1.15,
};

/// [base] with the proportions suited to [preset], or [base] unchanged for a
/// species with no entry.
AvatarFaceStyle tuneFaceForSpecies(String preset, AvatarFaceStyle base) {
  final face = _faces[preset];
  if (face == null) return base;
  final nose = face.nose;
  return base.tuned(
    // A touch larger than the table: small eyes read as cold, big ones as cute.
    // Never smaller than three quarters of what the illustrator drew, though:
    // the table's character is worth nothing if the eyes are too small for an
    // expression to be read from them.
    width: math.max(
      face.w * 1.2,
      base.width * math.max(_minimumEyeScale, _eyeBoost[preset] ?? 0),
    ),
    height: math.max(
      face.h * 1.2,
      base.height * math.max(_minimumEyeScale, _eyeBoost[preset] ?? 0),
    ),
    gap: face.gap,
    leftEyeRotation: face.tilt,
    rightEyeRotation: -face.tilt,
    noseEnabled: nose != null,
    noseWidth: nose?.$1,
    noseHeight: nose?.$2,
    noseY: face.noseY,
    mouthWidth: face.mouthW * 1.25,
    mouthHeight: face.mouthH * 1.25,
    mouthCurve: face.curve,
  );
}
