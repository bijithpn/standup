import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_face_expression.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_geometry.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_math.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_shape.dart';

/// Paints AvatarGeometry: outlines first, then parts, markings and face; front-standing parts (ears etc.) draw after the face host.
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
    this.rig = FaceRig.neutral,
    this.gaze = Offset.zero,
  });

  final AvatarGeometry geometry;
  final AvatarScene scene;

  final Color? background;

  final bool showOutline;
  final bool showShadow;

  final double fitPadding;

  final Rect? fitBounds;

  final double blush;

  final FaceRig rig;
  final Offset gaze;

  // Caps scale so the head never exceeds this fraction of the box, keeping big bodies from over-zooming.
  static const double _maxHeadFraction = 0.80;

  @override
  void paint(Canvas canvas, Size size) {
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background!);
    }
    if (geometry.parts.isEmpty) return;

    canvas.save();

    final bounds = fitBounds ?? geometry.bounds;
    final padding = math.max(fitPadding, scene.framePadding);
    final extent = math.max(bounds.width, bounds.height) * (1 + padding * 2);
    final box = math.min(size.width, size.height);
    var scale = extent <= 0 ? 1.0 : box / extent;
    final headExtent = _headExtent();
    if (headExtent > 0) {
      scale = math.min(scale, box * _maxHeadFraction / headExtent);
    }

    canvas.translate(size.width / 2, size.height / 2);

    canvas.scale(scale);
    if (scene.viewState.roll != 0) canvas.rotate(scene.viewState.roll);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);

    if (showShadow && scene.showAvatarShadow) _paintShadow(canvas);

    for (final part in geometry.parts) {
      _paintOutline(canvas, part);
    }

    if (geometry.visibleRegions.isNotEmpty) {
      for (final part in geometry.parts) {
        final visible = geometry.visibleRegions[part.part.id];
        if (visible == null) continue;
        canvas.save();
        canvas.clipPath(visible, doAntiAlias: false);
        _paintPart(canvas, part);
        _paintMarkings(canvas, part);
        if (part.part.id == geometry.facePartId) _paintFace(canvas, part);
        canvas.restore();
      }
      canvas.restore();
      return;
    }

    for (final part in geometry.parts) {
      _paintPart(canvas, part);
      _paintMarkings(canvas, part);
      if (part.part.id == geometry.facePartId) _paintFace(canvas, part);
    }
    if (!scene.faceStyle.eyeShape.startsWith("reference-")) {
      _paintWhiskers(canvas);
    }

    canvas.restore();
  }

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

    final bounds = fitBounds ?? geometry.bounds;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bounds.center.dx, bounds.bottom - 3),
        width: bounds.width * .58,
        height: 12,
      ),
      Paint()
        ..color = style.color.withValues(alpha: style.opacity / 100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _paintOutline(Canvas canvas, PartGeometry geometry) {
    if (!showOutline || !scene.showOutline || scene.outlineStyle.width <= 0) {
      return;
    }
    if (geometry.part.shape == AvatarBodyShape.hookedBeak) return;
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

  void _paintPart(Canvas canvas, PartGeometry geometry) {
    final part = geometry.part;

    canvas.drawPath(geometry.outline, Paint()..color = part.baseColor);

    final mesh = geometry.mesh;
    if (mesh != null) canvas.drawVertices(mesh, BlendMode.dst, Paint());
  }

  Offset _projectLocal(AvatarPart part, double x, double y) {
    final spec = kShapeSpecs[part.shape]!;
    return _projectPoint(
      part,
      facePoint(spec, Vec2(x, y), options: part.shapeOptions),
    );
  }

  Offset _projectPoint(AvatarPart part, Vec3 p) {
    final rotated = rotateLocal(
      Vec3(p.x * part.scaleX, p.y * part.scaleY, p.z * part.scaleZ),
      rotationX: part.rotationX,
      rotationY: part.rotationY,
      rotationZ: part.rotationZ,
    );
    final v = rotateByPose(
      Vec3(rotated.x + part.x, rotated.y + part.y, rotated.z + part.z),
      scene.viewState.yaw,
      scene.viewState.pitch,
    );
    return Offset(v.x + kCenterX, v.y + kCenterY);
  }

  void _paintMarkings(Canvas canvas, PartGeometry host) {
    final part = host.part;
    final spec = kShapeSpecs[part.shape]!;
    canvas.save();
    canvas.clipPath(host.outline);
    for (final mark in scene.markings) {
      if (mark.targetPartId != part.id) continue;
      if (mark.surfaceRegions.isNotEmpty) {
        for (final region in mark.surfaceRegions) {
          final boundary = <Vec3>[];
          for (final sample in region) {
            final n = normalize(
              Vec3(
                sample.normal.x / part.scaleX,
                sample.normal.y / part.scaleY,
                sample.normal.z / part.scaleZ,
              ),
            );
            final rotated = rotateLocal(
              n,
              rotationX: part.rotationX,
              rotationY: part.rotationY,
              rotationZ: part.rotationZ,
            );
            final facing = rotateByPose(
              rotated,
              scene.viewState.yaw,
              scene.viewState.pitch,
            ).z;
            final p = _projectPoint(part, sample.position);
            boundary.add(Vec3(p.dx, p.dy, facing));
          }
          final visible = clipToVisibleHemisphere(boundary);
          if (visible.length < 3) continue;
          canvas.drawPath(
            Path()
              ..addPolygon([for (final p in visible) Offset(p.x, p.y)], true),
            Paint()..color = mark.color.withValues(alpha: mark.opacity),
          );
        }
        continue;
      }
      final boundary = <Vec3>[];
      final angle = mark.rotation * math.pi / 180;
      for (var i = 0; i < 48; i++) {
        final t = i * math.pi * 2 / 48;
        final dx = math.cos(t) * spec.radiusX * mark.width / 200;
        final dy = math.sin(t) * spec.radiusY * mark.height / 200;
        final x =
            spec.radiusX * mark.x / 100 +
            dx * math.cos(angle) -
            dy * math.sin(angle);
        final y =
            spec.radiusY * mark.y / 100 +
            dx * math.sin(angle) +
            dy * math.cos(angle);
        final n = faceNormal(spec, Vec2(x, y), options: part.shapeOptions);
        final facing = rotateByPose(
          normalize(
            Vec3(n.x / part.scaleX, n.y / part.scaleY, n.z / part.scaleZ),
          ),
          scene.viewState.yaw,
          scene.viewState.pitch,
        ).z;
        final p = _projectLocal(part, x, y);
        boundary.add(Vec3(p.dx, p.dy, facing));
      }
      final visible = clipToVisibleHemisphere(boundary);
      if (visible.length < 3) continue;
      final path = Path()
        ..addPolygon([for (final p in visible) Offset(p.x, p.y)], true);
      canvas.drawPath(
        path,
        Paint()..color = mark.color.withValues(alpha: mark.opacity),
      );
    }
    canvas.restore();
  }

  void _paintWhiskers(Canvas canvas) {
    if (!{
      'cat',
      'seal',
      'otter',
      'rabbit',
      'chinchilla',
      'hamster',
      'tiger',
      'lion',
    }.contains(scene.preset)) {
      return;
    }
    final head = scene.facePart;
    if (head == null) return;
    final spec = kShapeSpecs[head.shape]!;
    for (final sign in [-1, 1]) {
      for (var row = 0; row < 3; row++) {
        final startY = 49.0 + row * 7;
        final anchor = facePoint(
          spec,
          Vec2(sign * 32.0, startY),
          options: head.shapeOptions,
        );
        final normal = faceNormal(
          spec,
          Vec2(sign * 32.0, startY),
          options: head.shapeOptions,
        );
        if (rotateByPose(normal, scene.viewState.yaw, scene.viewState.pitch).z <
            .1) {
          continue;
        }
        final outline = <Offset>[];
        for (final edge in [1, -1]) {
          for (var sample = 0; sample <= 16; sample++) {
            final t = edge == 1 ? sample / 16 : 1 - sample / 16;
            final p = Vec3(
              sign * (32 + t * 103),
              startY + (row - 1) * 17 * t - 6 * t * t + edge * .55 * (1 - t),
              anchor.z - 7 * t * t,
            );
            outline.add(_projectPoint(head, p));
          }
        }
        final path = Path()..addPolygon(outline, true);
        canvas.drawPath(
          path,
          Paint()..color = head.foregroundColor.withValues(alpha: .25),
        );
      }
    }
  }

  void _paintBlush(Canvas canvas, FaceGeometry face) {
    final boxes = face.eyes.map((eye) => eye.path.getBounds()).toList();
    final mid =
        boxes.map((b) => b.center.dx).reduce((a, b) => a + b) / boxes.length;
    final paint = Paint()
      ..color = const Color(0xFFFF7A93).withValues(alpha: 0.08 * blush);
    final puff = 1 + rig.cheek * 0.25;
    for (final box in boxes) {
      final outward = box.center.dx >= mid ? 1.0 : -1.0;
      final radius = math.max(box.width, box.height) * 0.62;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            box.center.dx + outward * box.width * 0.55,
            box.bottom + radius * (0.75 - rig.cheek * 0.2),
          ),
          width: radius * 1.9 * puff,
          height: radius * 1.15 * puff,
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

    if (!scene.faceStyle.eyeShape.startsWith('reference-') &&
        blush > 0.02 &&
        face.eyes.length >= 2) {
      _paintBlush(canvas, face);
    }

    for (final eye in face.eyes) {
      final box = eye.path.getBounds();
      if (scene.faceStyle.eyeShape.startsWith('reference-')) {
        canvas.drawPath(eye.path, ink);
        continue;
      }
      canvas.save();
      canvas.translate(box.center.dx, box.center.dy);
      canvas.scale(1.12, 1.09);
      canvas.translate(-box.center.dx, -box.center.dy);
      canvas.drawPath(
        eye.path,
        Paint()..color = host.part.shadowColor.withValues(alpha: .22),
      );
      canvas.restore();
      canvas.drawPath(
        eye.path,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.35, -.4),
            radius: .9,
            colors: [
              const Color(0xff635747),
              host.part.foregroundColor,
              const Color(0xff171d21),
            ],
          ).createShader(box),
      );
      if (box.height > box.width * .45) {
        canvas.save();
        canvas.clipPath(eye.path);
        canvas.drawOval(
          Rect.fromCenter(
            center:
                box.center +
                Offset(
                  gaze.dx.clamp(-1.0, 1.0) * box.width * .14,
                  gaze.dy.clamp(-1.0, 1.0) * box.height * .12,
                ),
            width: box.width * .62,
            height: box.height * .80,
          ),
          Paint()..color = const Color(0xff1a2023),
        );
        canvas.restore();
      }
    }

    if (!_hasOwnMouthParts ||
        scene.faceStyle.eyeShape.startsWith("reference-")) {
      final nose = face.nose;
      if (nose != null) {
        final c = nose.path.getBounds().center;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(1 + rig.nose * 0.3);
        canvas.translate(-c.dx, -c.dy - rig.nose);
        canvas.drawPath(nose.path, ink);
        canvas.restore();
      }
    }

    if (face.mouth != null &&
        !scene.parts.any(
          (p) => p.id.startsWith('beak') || p.id.startsWith('bill'),
        )) {
      canvas.drawPath(face.mouth!.path, ink);
    }
    if (face.highlights.isEmpty) return;
    final highlight = Paint()
      ..color = scene.faceStyle.highlightColor.withValues(
        alpha: (scene.faceStyle.highlightOpacity / 100).clamp(0.0, 1.0),
      );
    for (var i = 0; i < face.highlights.length && i < face.eyes.length; i++) {
      canvas.save();
      canvas.clipPath(face.eyes[i].path);
      canvas.drawPath(face.highlights[i].path, highlight);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant AvatarScenePainter oldDelegate) {
    return !identical(oldDelegate.geometry, geometry) ||
        oldDelegate.background != background ||
        oldDelegate.showOutline != showOutline ||
        oldDelegate.showShadow != showShadow ||
        oldDelegate.blush != blush ||
        oldDelegate.gaze != gaze ||
        !identical(oldDelegate.rig, rig);
  }
}
