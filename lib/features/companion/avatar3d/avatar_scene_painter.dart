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
    this.fitPadding = 0.09,
    this.fitBounds,
    this.blush = 0,
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

  /// Rosy cheeks, 0..1.
  final double blush;

  /// The share of the widget the head may fill. Species with big ears or manes
  /// are limited by their silhouette; compact ones would otherwise fill the box
  /// and look oversized next to them.
  static const double _maxHeadFraction = 0.74;

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
    final box = math.min(size.width, size.height);
    var scale = extent <= 0 ? 1.0 : box / extent;
    final headExtent = _headExtent();
    if (headExtent > 0) {
      scale = math.min(scale, box * _maxHeadFraction / headExtent);
    }

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
      _paintMarkings(canvas, part);
      if (part.part.id == geometry.facePartId) faceHost = part;
    }
    // The face goes on last. Cheeks, muzzles and snouts are separate parts
    // drawn after the head, and painting the face straight after its host let
    // them cover the eyes completely on a chinchilla, hamster or seal.
    if (faceHost != null) _paintFace(canvas, faceHost);

    canvas.restore();
  }

  /// The head's largest dimension in scene units, or 0 if there is no head.
  /// A head's longest side barely changes as it turns, so this does not make
  /// the pet breathe in and out.
  double _headExtent() {
    for (final part in geometry.parts) {
      if (part.part.id != geometry.facePartId) continue;
      final box = part.outline.getBounds();
      return math.max(box.width, box.height);
    }
    return 0;
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

  /// Colour marks on [host], clipped to its silhouette. Marks on the head drift
  /// with the face so they stay put on the head as it turns.
  void _paintMarkings(Canvas canvas, PartGeometry host) {
    if (scene.markings.isEmpty) return;
    final box = host.outline.getBounds();
    if (box.isEmpty) return;

    // The nose sits on the face's centre line, so anchoring to it keeps a
    // muzzle under the nose however far the head has turned.
    final nose = geometry.face.nose;
    final eyes = geometry.face.eyes;
    var drift = 0.0;
    if (nose != null) {
      drift = nose.path.getBounds().center.dx - box.center.dx;
    } else if (eyes.isNotEmpty) {
      final eyeX =
          eyes
              .map((e) => e.path.getBounds().center.dx)
              .reduce((a, b) => a + b) /
          eyes.length;
      drift = eyeX - box.center.dx;
    }

    canvas.save();
    canvas.clipPath(host.outline);
    for (final mark in scene.markings) {
      if (mark.targetPartId != host.part.id) continue;
      final k = mark.onFace ? 0.5 : 0.9;
      final center = Offset(
        box.center.dx + box.width * mark.x / 200 + (mark.onFace ? drift : 0),
        box.center.dy + box.height * mark.y / 200,
      );
      final size = Size(
        box.width * mark.width * k / 100,
        box.height * mark.height * k / 100,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(mark.rotation * math.pi / 180);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: size.width,
        height: size.height,
      );
      final paint = Paint()..color = mark.color.withValues(alpha: mark.opacity);
      if (mark.shape == 'rounded-triangle') {
        canvas.drawPath(
          Path()
            ..moveTo(0, rect.top)
            ..quadraticBezierTo(rect.right, rect.bottom, rect.left, rect.bottom)
            ..quadraticBezierTo(rect.left, rect.bottom, 0, rect.top),
          paint,
        );
      } else {
        canvas.drawOval(rect, paint);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  /// Soft pink patches below and outside the eyes.
  void _paintBlush(Canvas canvas, FaceGeometry face) {
    final boxes = face.eyes.map((eye) => eye.path.getBounds()).toList();
    final mid =
        boxes.map((b) => b.center.dx).reduce((a, b) => a + b) / boxes.length;
    final paint = Paint()
      ..color = const Color(0xFFFF7A93).withValues(alpha: 0.5 * blush);
    for (final box in boxes) {
      final outward = box.center.dx >= mid ? 1.0 : -1.0;
      final radius = math.max(box.width, box.height) * 0.62;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            box.center.dx + outward * box.width * 0.55,
            box.bottom + radius * 0.75,
          ),
          width: radius * 1.9,
          height: radius * 1.15,
        ),
        paint,
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

    if (blush > 0.02 && face.eyes.length >= 2) _paintBlush(canvas, face);

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
        oldDelegate.showShadow != showShadow ||
        oldDelegate.blush != blush;
  }
}
