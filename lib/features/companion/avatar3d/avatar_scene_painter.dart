import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_geometry.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_math.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';

/// Draws a built [AvatarGeometry].
///
/// The order is the editor's: drop shadow, then each part back-to-front as
/// outline, body, shaded cells, then the face on top of the part that owns it.
class AvatarScenePainter extends CustomPainter {
  AvatarScenePainter({
    required this.geometry,
    required this.scene,
    this.background,
    this.showOutline = true,
    this.showShadow = true,
    this.fitPadding = 0.06,
    this.fitBounds,
  });

  final AvatarGeometry geometry;
  final AvatarScene scene;

  /// Painted behind the avatar. Null leaves the canvas untouched, which is what
  /// the floating companion wants.
  final Color? background;

  final bool showOutline;
  final bool showShadow;

  /// Fraction of the fitted size left as breathing room around the silhouette.
  final double fitPadding;

  /// The silhouette to fit to, when the caller wants a steady size across
  /// poses. Defaults to this frame's own.
  final Rect? fitBounds;

  @override
  void paint(Canvas canvas, Size size) {
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background!);
    }
    if (geometry.parts.isEmpty) return;

    canvas.save();

    // Fit the scene's own silhouette to the widget, so every species arrives
    // the same size and centred no matter where it was authored in frame.
    final bounds = fitBounds ?? geometry.bounds;
    final extent = math.max(bounds.width, bounds.height) * (1 + fitPadding * 2);
    final scale = extent <= 0
        ? 1.0
        : math.min(size.width, size.height) / extent;

    canvas.translate(size.width / 2, size.height / 2);
    // The scene's own `scale` and `position` are the editor's framing inside
    // its 420-unit view box. Fitting the silhouette already does that job, and
    // applying both zooms the companion until only its face is left.
    canvas.scale(scale);
    if (scene.viewState.roll != 0) canvas.rotate(scene.viewState.roll);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);

    if (showShadow && scene.showAvatarShadow) _paintShadow(canvas);

    PartGeometry? faceHost;
    for (final part in geometry.parts) {
      _paintPart(canvas, part);
      if (part.part.id == geometry.facePartId) faceHost = part;
    }
    // The face goes on last. Cheeks, muzzles and snouts are separate parts
    // drawn after the head, and painting the face straight after its host let
    // them cover the eyes completely on a chinchilla, hamster or seal.
    if (faceHost != null) _paintFace(canvas, faceHost);

    canvas.restore();
  }

  void _paintShadow(Canvas canvas) {
    final style = scene.shadowStyle;
    if (style.opacity <= 0 || style.distance <= 0) return;

    final radians = style.direction * math.pi / 180;
    final offset = Offset(
      math.cos(radians) * style.distance,
      math.sin(radians) * style.distance,
    );
    final paint = Paint()
      ..color = style.color.withValues(alpha: (style.opacity / 100).clamp(0, 1))
      ..maskFilter = style.softness > 0
          ? MaskFilter.blur(BlurStyle.normal, style.softness / 2)
          : null;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    for (final part in geometry.parts) {
      canvas.drawPath(part.outline, paint);
    }
    canvas.restore();
  }

  void _paintPart(Canvas canvas, PartGeometry geometry) {
    final part = geometry.part;

    if (showOutline && scene.showOutline && scene.outlineStyle.width > 0) {
      final outline = scene.outlineStyle;
      canvas.drawPath(
        geometry.outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outline.width
          ..strokeJoin = StrokeJoin.round
          ..color = outline.color.withValues(
            alpha: (outline.opacity / 100).clamp(0, 1),
          ),
      );
    }

    // A solid base under the cells: the cells only cover the lit hemisphere,
    // and without this the silhouette's edge shows canvas through the seams.
    canvas.drawPath(geometry.outline, Paint()..color = part.baseColor);

    for (final cell in geometry.cells) {
      final opacity = surfaceShadeOpacity(cell.shade, scene.lightDistance);
      if (opacity <= 0.004) continue;

      final tint = cell.shade >= 0 ? part.highlightColor : part.shadowColor;
      canvas.drawPath(
        cell.path,
        Paint()
          ..color = tint.withValues(alpha: opacity.clamp(0.0, 1.0))
          // Anti-aliasing every cell edge leaves visible seams between
          // neighbours; the silhouette is what carries the smooth edge.
          ..isAntiAlias = false,
      );
    }
  }

  static final RegExp _mouthPartId = RegExp(
    'beak|bill|snout|muzzle|tooth|teeth|nose',
  );

  bool get _hasOwnMouthParts =>
      scene.parts.any((part) => _mouthPartId.hasMatch(part.id));

  void _paintFace(Canvas canvas, PartGeometry host) {
    final face = geometry.face;
    if (face.isEmpty) return;

    final ink = Paint()..color = host.part.foregroundColor;

    for (final eye in face.eyes) {
      canvas.drawPath(eye.path, ink);
    }
    // A species with its own beak, bill, snout or muzzle already has a
    // mouth. Drawing the face's one on top of it put a smile on the bill.
    if (!_hasOwnMouthParts) {
      if (face.nose != null) canvas.drawPath(face.nose!.path, ink);
      if (face.mouth != null) canvas.drawPath(face.mouth!.path, ink);
    }

    if (face.highlights.isEmpty) return;
    final highlight = Paint()
      ..color = scene.faceStyle.highlightColor.withValues(
        alpha: (scene.faceStyle.highlightOpacity / 100).clamp(0.0, 1.0),
      );
    for (final spark in face.highlights) {
      canvas.drawPath(spark.path, highlight);
    }
  }

  @override
  bool shouldRepaint(covariant AvatarScenePainter oldDelegate) {
    return !identical(oldDelegate.geometry, geometry) ||
        oldDelegate.background != background ||
        oldDelegate.showOutline != showOutline ||
        oldDelegate.showShadow != showShadow;
  }
}
