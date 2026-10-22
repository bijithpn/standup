import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';

/// Recolours an authored scene with a user-chosen palette.
///
/// The scenes ship with the colours their illustrator picked, which is what
/// makes them look right. A palette has to change those without flattening the
/// modelling: each part carries a base, a lit side, a shadowed side and an ink
/// colour, and the difference between them *is* the shading. So colours are
/// remapped by role, keeping each one's own lightness, rather than replaced.
///
/// Parts that shared a colour still share it afterwards, which is what keeps a
/// pair of ears matching.

/// Applies [palette] to [scene], or returns it untouched when there is nothing
/// to apply.
///
/// [strength] of 0 leaves the authored colours alone; 1 pulls fully to the
/// palette.
AvatarScene applyPalette(
  AvatarScene scene,
  AvatarPalette? palette, {
  double strength = 0.85,
}) {
  if (palette == null || strength <= 0) return scene;

  final substitutions = _buildSubstitutions(scene, palette, strength);
  if (substitutions.isEmpty) return scene;

  Color map(Color original) => substitutions[original.toARGB32()] ?? original;

  final parts = <AvatarPart>[
    for (final part in scene.parts)
      AvatarPart(
        id: part.id,
        label: part.label,
        shape: part.shape,
        x: part.x,
        y: part.y,
        z: part.z,
        scaleX: part.scaleX,
        scaleY: part.scaleY,
        scaleZ: part.scaleZ,
        rotationX: part.rotationX,
        rotationY: part.rotationY,
        rotationZ: part.rotationZ,
        baseColor: map(part.baseColor),
        foregroundColor: map(part.foregroundColor),
        highlightColor: map(part.highlightColor),
        shadowColor: map(part.shadowColor),
        hasFace: part.hasFace,
        occludedByFace: part.occludedByFace,
        roundness: part.roundness,
        topScale: part.topScale,
        bottomTaper: part.bottomTaper,
        cutAngle: part.cutAngle,
      ),
  ];

  return scene.copyWithParts(
    parts,
    outlineStyle: AvatarOutlineStyle(
      color: map(scene.outlineStyle.color),
      opacity: scene.outlineStyle.opacity,
      width: scene.outlineStyle.width,
    ),
  );
}

/// Builds the authored-colour → palette-colour table for one scene.
Map<int, Color> _buildSubstitutions(
  AvatarScene scene,
  AvatarPalette palette,
  double strength,
) {
  // How much of the avatar each colour covers, approximated by the part's
  // volume. A colour on the head should take the body role, not one on an ear.
  final coverage = <int, double>{};
  final inkCandidates = <int>{};

  for (final part in scene.parts) {
    final volume = (part.scaleX * part.scaleY * part.scaleZ).abs().clamp(
      0.0001,
      100.0,
    );
    void add(Color colour, double weight) {
      final key = colour.toARGB32();
      coverage[key] = (coverage[key] ?? 0) + volume * weight;
    }

    add(part.baseColor, 1.0);
    // The lit and shadowed sides are variations of the base, so they carry
    // less weight in deciding which role a colour plays.
    add(part.highlightColor, 0.25);
    add(part.shadowColor, 0.25);
    inkCandidates.add(part.foregroundColor.toARGB32());
  }

  if (coverage.isEmpty) return const <int, Color>{};

  final roles = <Color?>[
    _parse(palette.primary),
    _parse(palette.secondary),
    _parse(palette.accent),
    _parse(palette.belly),
    _parse(palette.snout),
  ].whereType<Color>().toList();
  if (roles.isEmpty) return const <int, Color>{};

  final ink = _parse(palette.eyes);

  final ordered = coverage.keys.toList()
    ..sort((a, b) => coverage[b]!.compareTo(coverage[a]!));

  final substitutions = <int, Color>{};
  var roleIndex = 0;

  for (final key in ordered) {
    final source = Color(key);

    // Ink stays ink. Eyes and outlines drawn in the body colour would erase
    // the face entirely.
    if (inkCandidates.contains(key) &&
        ink != null &&
        _luminance(source) < 0.4) {
      substitutions[key] = _reshade(source, ink, strength * 0.7);
      continue;
    }

    substitutions[key] = _reshade(
      source,
      roles[roleIndex % roles.length],
      strength,
    );
    roleIndex++;
  }

  // Any ink colour that was light enough to take a body role still needs to
  // read as ink somewhere, so map the remainder explicitly.
  if (ink != null) {
    for (final key in inkCandidates) {
      substitutions.putIfAbsent(
        key,
        () => _reshade(Color(key), ink, strength * 0.7),
      );
    }
  }

  return substitutions;
}

Color? _parse(String hex) {
  var value = hex.startsWith('#') ? hex.substring(1) : hex;
  if (value.length == 3) {
    value = value.split('').map((c) => '$c$c').join();
  }
  if (value.length != 6) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}

double _luminance(Color colour) =>
    0.2126 * (colour.r) + 0.7152 * (colour.g) + 0.0722 * (colour.b);

/// Takes [target]'s hue and saturation but keeps much of [source]'s lightness,
/// so a highlight stays a highlight and a shadow stays a shadow.
Color _reshade(Color source, Color target, double strength) {
  final sourceHsl = _Hsl.from(source);
  final targetHsl = _Hsl.from(target);

  final blended = _Hsl(
    targetHsl.hue,
    targetHsl.saturation,
    targetHsl.lightness + (sourceHsl.lightness - targetHsl.lightness) * 0.5,
  ).toColor(source.a);

  final t = strength.clamp(0.0, 1.0);
  return Color.from(
    alpha: source.a,
    red: source.r + (blended.r - source.r) * t,
    green: source.g + (blended.g - source.g) * t,
    blue: source.b + (blended.b - source.b) * t,
  );
}

class _Hsl {
  const _Hsl(this.hue, this.saturation, this.lightness);

  final double hue;
  final double saturation;
  final double lightness;

  static _Hsl from(Color colour) {
    final r = colour.r;
    final g = colour.g;
    final b = colour.b;
    final maxV = math.max(r, math.max(g, b));
    final minV = math.min(r, math.min(g, b));
    final lightness = (maxV + minV) / 2;
    if (maxV == minV) return _Hsl(0, 0, lightness);

    final d = maxV - minV;
    final saturation = lightness > 0.5
        ? d / (2 - maxV - minV)
        : d / (maxV + minV);
    double hue;
    if (maxV == r) {
      hue = (g - b) / d + (g < b ? 6 : 0);
    } else if (maxV == g) {
      hue = (b - r) / d + 2;
    } else {
      hue = (r - g) / d + 4;
    }
    return _Hsl(hue / 6, saturation, lightness);
  }

  Color toColor(double alpha) {
    if (saturation == 0) {
      return Color.from(
        alpha: alpha,
        red: lightness,
        green: lightness,
        blue: lightness,
      );
    }

    final q = lightness < 0.5
        ? lightness * (1 + saturation)
        : lightness + saturation - lightness * saturation;
    final p = 2 * lightness - q;

    return Color.from(
      alpha: alpha,
      red: _channel(p, q, hue + 1 / 3),
      green: _channel(p, q, hue),
      blue: _channel(p, q, hue - 1 / 3),
    );
  }

  static double _channel(double p, double q, double t) {
    var v = t;
    if (v < 0) v += 1;
    if (v > 1) v -= 1;
    if (v < 1 / 6) return p + (q - p) * 6 * v;
    if (v < 1 / 2) return q;
    if (v < 2 / 3) return p + (q - p) * (2 / 3 - v) * 6;
    return p;
  }
}
