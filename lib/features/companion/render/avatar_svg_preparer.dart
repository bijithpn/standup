import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/render/avatar_artwork_recipe.dart';

final RegExp _backdropPlate = RegExp(
  r'(<svg\b[^>]*>)\s*<rect\b[^>]*\bwidth="\d+(?:\.\d+)?"[^>]*\bheight="\d+(?:\.\d+)?"[^>]*>\s*(?:</rect>)?',
);

final RegExp _filterRef = RegExp(r'\s*filter="url\(#[^)]*\)"');

final RegExp _filterDef = RegExp(r'<filter\b[^>]*>.*?</filter>', dotAll: true);

final RegExp _emptyClipDef = RegExp(
  r'<clipPath\b[^>]*\bid="([^"]+)"[^>]*>\s*<path\s+d=""\s*>\s*</path>\s*</clipPath>',
);

final RegExp _emptyDefs = RegExp(r'<defs\b[^>]*>\s*</defs>');

final RegExp _colorAttr = RegExp(
  r'(fill|stroke|flood-color|stop-color)="(#[0-9a-fA-F]{3,8})"',
);

/// Removes the backdrop plate, filters and empty clip paths from the authored SVG.
String stripAvatarChrome(String raw, {required bool transparentBackdrop}) {
  var svg = raw;

  if (transparentBackdrop) {
    svg = svg.replaceFirstMapped(_backdropPlate, (m) => m.group(1)!);
  }

  svg = svg.replaceAll(_filterRef, '').replaceAll(_filterDef, '');

  for (final match in _emptyClipDef.allMatches(svg).toList()) {
    final id = match.group(1)!;
    svg = svg.replaceAll(
      RegExp('\\s*clip-path="url\\(#${RegExp.escape(id)}\\)"'),
      '',
    );
  }
  svg = svg.replaceAll(_emptyClipDef, '').replaceAll(_emptyDefs, '');

  return svg;
}

int? parseCssColor(String hex) {
  var h = hex.startsWith('#') ? hex.substring(1) : hex;
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length == 6) {
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : 0xFF000000 | v;
  }
  if (h.length == 8) {
    final v = int.tryParse(h, radix: 16);

    return v == null ? null : ((v & 0xFF) << 24) | (v >> 8);
  }
  return null;
}

int? _backdropColorOf(String raw) {
  final plate = _backdropPlate.firstMatch(raw);
  if (plate == null) return null;
  final fill = _colorAttr.firstMatch(plate.group(0)!);
  return fill == null ? null : parseCssColor(fill.group(2)!);
}

double _luminance(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255.0;
  final g = ((argb >> 8) & 0xFF) / 255.0;
  final b = (argb & 0xFF) / 255.0;
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

class _AuthoredColor {
  _AuthoredColor(this.argb, this.firstSeen);

  final int argb;
  final int firstSeen;
  int count = 0;
}

List<_AuthoredColor> _histogram(String raw, {int? backdrop}) {
  final byColor = <int, _AuthoredColor>{};
  var index = 0;
  var backdropSkipped = backdrop == null;

  for (final match in _colorAttr.allMatches(raw)) {
    final argb = parseCssColor(match.group(2)!);
    if (argb == null) continue;
    if (!backdropSkipped && argb == backdrop) {
      backdropSkipped = true;
      continue;
    }
    (byColor[argb] ??= _AuthoredColor(argb, index++)).count++;
  }

  return byColor.values.toList()..sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : a.firstSeen.compareTo(b.firstSeen);
  });
}

class _Hsl {
  const _Hsl(this.h, this.s, this.l);
  final double h;
  final double s;
  final double l;
}

_Hsl _toHsl(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255.0;
  final g = ((argb >> 8) & 0xFF) / 255.0;
  final b = (argb & 0xFF) / 255.0;
  final maxV = math.max(r, math.max(g, b));
  final minV = math.min(r, math.min(g, b));
  final l = (maxV + minV) / 2.0;
  if (maxV == minV) return _Hsl(0.0, 0.0, l);

  final d = maxV - minV;
  final s = l > 0.5 ? d / (2.0 - maxV - minV) : d / (maxV + minV);
  double h;
  if (maxV == r) {
    h = (g - b) / d + (g < b ? 6.0 : 0.0);
  } else if (maxV == g) {
    h = (b - r) / d + 2.0;
  } else {
    h = (r - g) / d + 4.0;
  }
  return _Hsl(h / 6.0, s, l);
}

double _hueToChannel(double p, double q, double t) {
  var v = t;
  if (v < 0) v += 1;
  if (v > 1) v -= 1;
  if (v < 1 / 6) return p + (q - p) * 6 * v;
  if (v < 1 / 2) return q;
  if (v < 2 / 3) return p + (q - p) * (2 / 3 - v) * 6;
  return p;
}

int _fromHsl(_Hsl hsl, int alpha) {
  if (hsl.s == 0) {
    final v = (hsl.l * 255).round().clamp(0, 255);
    return (alpha << 24) | (v << 16) | (v << 8) | v;
  }
  final q = hsl.l < 0.5 ? hsl.l * (1 + hsl.s) : hsl.l + hsl.s - hsl.l * hsl.s;
  final p = 2 * hsl.l - q;
  final r = (_hueToChannel(p, q, hsl.h + 1 / 3) * 255).round().clamp(0, 255);
  final g = (_hueToChannel(p, q, hsl.h) * 255).round().clamp(0, 255);
  final b = (_hueToChannel(p, q, hsl.h - 1 / 3) * 255).round().clamp(0, 255);
  return (alpha << 24) | (r << 16) | (g << 8) | b;
}

int _lerpColor(int a, int b, double t) {
  int channel(int shift) {
    final av = (a >> shift) & 0xFF;
    final bv = (b >> shift) & 0xFF;
    return (av + (bv - av) * t).round().clamp(0, 255);
  }

  return (channel(24) << 24) |
      (channel(16) << 16) |
      (channel(8) << 8) |
      channel(0);
}

int _reshade(int source, int target, double strength) {
  final sourceHsl = _toHsl(source);
  final targetHsl = _toHsl(target);
  final blended = _fromHsl(
    _Hsl(
      targetHsl.h,
      targetHsl.s,
      targetHsl.l + (sourceHsl.l - targetHsl.l) * 0.45,
    ),
    (source >> 24) & 0xFF,
  );
  return _lerpColor(source, blended, strength.clamp(0.0, 1.0));
}

/// Maps the SVG's most-used authored colors onto palette colors, so any breed art can be recolored.
Map<int, int> buildPaletteSubstitutions(
  String raw,
  AvatarPalette palette,
  double strength,
) {
  final colors = _histogram(raw, backdrop: _backdropColorOf(raw));
  if (colors.isEmpty) return const <int, int>{};

  final roles = <String>[
    palette.primary,
    palette.secondary,
    palette.accent,
    palette.belly,
    palette.snout,
  ].map(parseCssColor).whereType<int>().toList();
  if (roles.isEmpty) return const <int, int>{};

  final ink = parseCssColor(palette.eyes);

  var darkest = colors.first;
  for (final color in colors) {
    if (_luminance(color.argb) < _luminance(darkest.argb)) darkest = color;
  }

  final substitutions = <int, int>{};
  var roleIndex = 0;
  for (final color in colors) {
    if (identical(color, darkest) &&
        ink != null &&
        _luminance(color.argb) < 0.3) {
      substitutions[color.argb] = _reshade(color.argb, ink, strength * 0.75);
      continue;
    }
    substitutions[color.argb] = _reshade(
      color.argb,
      roles[roleIndex % roles.length],
      strength,
    );
    roleIndex++;
  }
  return substitutions;
}

final RegExp _viewBoxAttr = RegExp(r'viewBox="([^"]*)"');

final Map<String, ArtworkBounds?> _boundsCache = <String, ArtworkBounds?>{};

class ArtworkBounds {
  const ArtworkBounds(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  bool get isUseful => width > 0 && height > 0;
}

/// Measures the drawn content bounds so the viewBox can be recentred on the pet.
ArtworkBounds? measureContent(String preparedSvg, String debugName) {
  final VectorInstructions instructions;
  try {
    instructions = parse(
      preparedSvg,
      key: debugName,
      enableMaskingOptimizer: false,
      enableClippingOptimizer: false,
      enableOverdrawOptimizer: false,
    );
  } catch (_) {
    return null;
  }

  double? left, top, right, bottom;
  for (final path in instructions.paths) {
    final box = path.bounds();
    if (!box.left.isFinite || !box.top.isFinite) continue;
    left = left == null || box.left < left ? box.left : left;
    top = top == null || box.top < top ? box.top : top;
    right = right == null || box.right > right ? box.right : right;
    bottom = bottom == null || box.bottom > bottom ? box.bottom : bottom;
  }

  if (left == null || top == null || right == null || bottom == null) {
    return null;
  }
  final bounds = ArtworkBounds(left, top, right, bottom);
  return bounds.isUseful ? bounds : null;
}

String recenterViewBox(
  String svg,
  ArtworkBounds bounds, {
  double padding = 0.06,
}) {
  final side = math.max(bounds.width, bounds.height) * (1 + padding * 2);
  if (side <= 0) return svg;

  final left = bounds.centerX - side / 2;
  final top = bounds.centerY - side / 2;
  final viewBox =
      'viewBox="${_trim(left)} ${_trim(top)} '
      '${_trim(side)} ${_trim(side)}"';

  if (_viewBoxAttr.hasMatch(svg)) {
    return svg.replaceFirst(_viewBoxAttr, viewBox);
  }

  return svg.replaceFirst(RegExp(r'<svg\b'), '<svg $viewBox');
}

String _trim(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

class _SubstitutionColorMapper extends ColorMapper {
  _SubstitutionColorMapper(this._table);

  final Map<int, int> _table;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    final replacement = _table[color.value];
    return replacement == null ? color : Color(replacement);
  }
}

/// Full pipeline: strip chrome, recenter, build palette substitutions, encode to vector_graphics bytes.
Uint8List compileAvatarArtwork(AvatarArtworkRecipe recipe, String rawSvg) {
  var prepared = stripAvatarChrome(
    rawSvg,
    transparentBackdrop: recipe.transparentBackdrop,
  );

  if (recipe.transparentBackdrop && recipe.centerContent) {
    final bounds = _boundsCache.putIfAbsent(
      recipe.assetKey,
      () => measureContent(prepared, recipe.assetKey),
    );
    if (bounds != null) prepared = recenterViewBox(prepared, bounds);
  }

  final palette = recipe.palette;
  final substitutions = palette == null
      ? const <int, int>{}
      : buildPaletteSubstitutions(prepared, palette, recipe.paletteStrength);

  return encodeSvg(
    xml: prepared,
    debugName: recipe.assetKey,
    warningsAsErrors: false,
    enableMaskingOptimizer: false,
    enableClippingOptimizer: false,
    enableOverdrawOptimizer: false,
    colorMapper: substitutions.isEmpty
        ? null
        : _SubstitutionColorMapper(substitutions),
  );
}
