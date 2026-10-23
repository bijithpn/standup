import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:breakmate/features/companion/avatar3d/avatar_math.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_shape.dart';

/// Turns a scene plus a camera pose into drawable geometry.
///
/// Ported from `buildAvatarBodyGeometry` and `projectDefaultFace`. Where the
/// original emits SVG path strings, this builds `ui.Path` directly — the paths
/// are the output, so there is no reason to go through text.

/// One quad of a primitive's surface, with how lit it is and how far away.
class SurfaceCell {
  const SurfaceCell(this.path, this.shade, this.depth);

  final ui.Path path;

  /// -1 fully shadowed, 0 edge-on, 1 fully lit.
  final double shade;
  final double depth;
}

/// Everything needed to draw one part.
class PartGeometry {
  const PartGeometry({
    required this.part,
    required this.cells,
    required this.outline,
    required this.depth,
  });

  final AvatarPart part;
  final List<SurfaceCell> cells;

  /// The silhouette, used for the outline stroke and the drop shadow.
  final ui.Path outline;

  /// Mean depth of the part, for sorting parts against each other.
  final double depth;
}

/// A projected face feature.
class FaceFeature {
  const FaceFeature(this.path, this.depth);

  final ui.Path path;
  final double depth;
}

class FaceGeometry {
  const FaceGeometry({
    required this.eyes,
    required this.highlights,
    this.nose,
    this.mouth,
  });

  final List<FaceFeature> eyes;
  final List<FaceFeature> highlights;
  final FaceFeature? nose;
  final FaceFeature? mouth;

  bool get isEmpty => eyes.isEmpty && nose == null && mouth == null;
}

/// The whole companion, ready to paint.
class AvatarGeometry {
  const AvatarGeometry({
    required this.parts,
    required this.face,
    required this.facePartId,
    required this.bounds,
  });

  final List<PartGeometry> parts;
  final FaceGeometry face;
  final String? facePartId;

  /// Union of every part's silhouette, in authored scene units.
  final ui.Rect bounds;
}

const int _baseLatitudeSteps = 14;
const int _baseLongitudeSteps = 28;
const int _outlineLatitudeSteps = 28;
const int _outlineLongitudeSteps = 72;
const int _ellipseSteps = 40;
const int _faceEdgeSteps = 8;
const double _minimumFacing = 0.015;

/// Builds the drawable geometry for [scene] at its current pose.
///
/// [densityScale] trims the tessellation for small or always-on surfaces; 1.0
/// is what the editor uses. Pure computation, so it is safe on any isolate.
AvatarGeometry buildAvatarGeometry(
  AvatarScene scene, {
  double densityScale = 1.0,
}) {
  final view = scene.viewState;
  final azimuth = scene.lightAzimuth * math.pi / 180;
  final elevation = scene.lightElevation * math.pi / 180;
  final light = normalize(
    Vec3(
      math.cos(elevation) * math.sin(azimuth),
      -math.sin(elevation),
      math.cos(elevation) * math.cos(azimuth),
    ),
  );

  final density =
      clampDouble(scene.gridDensity, 20, 200) /
      100 *
      clampDouble(densityScale, 0.25, 2);
  final latitudeSteps = math.max((_baseLatitudeSteps * density).round(), 4);
  final longitudeSteps = math.max((_baseLongitudeSteps * density).round(), 8);

  final parts = <PartGeometry>[];
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;

  for (final part in scene.parts) {
    final geometry = _buildPart(
      part,
      view,
      light,
      latitudeSteps: latitudeSteps,
      longitudeSteps: longitudeSteps,
    );
    parts.add(geometry);

    final box = geometry.outline.getBounds();
    if (box.isEmpty) continue;
    minX = math.min(minX, box.left);
    minY = math.min(minY, box.top);
    maxX = math.max(maxX, box.right);
    maxY = math.max(maxY, box.bottom);
  }

  // Far parts first, so nearer ones paint over them.
  parts.sort((left, right) => left.depth.compareTo(right.depth));

  final facePart = scene.facePart;
  final face = facePart == null
      ? const FaceGeometry(eyes: <FaceFeature>[], highlights: <FaceFeature>[])
      : _buildFace(facePart, scene.faceStyle, view);

  final bounds = minX.isFinite
      ? ui.Rect.fromLTRB(minX, minY, maxX, maxY)
      : ui.Rect.fromLTWH(0, 0, kViewSize, kViewSize);

  return AvatarGeometry(
    parts: parts,
    face: face,
    facePartId: facePart?.id,
    bounds: bounds,
  );
}

PartGeometry _buildPart(
  AvatarPart part,
  AvatarViewState view,
  Vec3 light, {
  required int latitudeSteps,
  required int longitudeSteps,
}) {
  final spec = kShapeSpecs[part.shape]!;
  final options = part.shapeOptions;

  // The part's own scale and rotation, then its offset, then the camera.
  Vec3 transformPoint(Vec3 point) {
    final scaled = Vec3(
      point.x * part.scaleX,
      point.y * part.scaleY,
      point.z * part.scaleZ,
    );
    final rotated = rotateLocal(
      scaled,
      rotationX: part.rotationX,
      rotationY: part.rotationY,
      rotationZ: part.rotationZ,
    );
    final placed = Vec3(
      rotated.x + part.x,
      rotated.y + part.y,
      rotated.z + part.z,
    );
    return rotateByPose(placed, view.yaw, view.pitch);
  }

  // Normals scale inversely, or a squashed primitive lights as if it were not.
  Vec3 transformNormal(Vec3 normal) {
    final scaled = normalize(
      Vec3(
        normal.x / part.scaleX,
        normal.y / part.scaleY,
        normal.z / part.scaleZ,
      ),
    );
    final rotated = rotateLocal(
      scaled,
      rotationX: part.rotationX,
      rotationY: part.rotationY,
      rotationZ: part.rotationZ,
    );
    return rotateByPose(rotated, view.yaw, view.pitch);
  }

  final cells = <SurfaceCell>[];
  var depthSum = 0.0;
  var depthCount = 0;

  for (var latIndex = 0; latIndex < latitudeSteps; latIndex++) {
    final latStart = -math.pi / 2 + latIndex / latitudeSteps * math.pi;
    final latEnd = -math.pi / 2 + (latIndex + 1) / latitudeSteps * math.pi;

    for (var lonIndex = 0; lonIndex < longitudeSteps; lonIndex++) {
      final lonStart = -math.pi + lonIndex / longitudeSteps * math.pi * 2;
      final lonEnd = -math.pi + (lonIndex + 1) / longitudeSteps * math.pi * 2;

      final normal = transformNormal(
        surfaceNormal(
          spec,
          (lonStart + lonEnd) / 2,
          (latStart + latEnd) / 2,
          options: options,
        ),
      );
      // Back-facing cells are simply not drawn; that is the hidden-surface
      // removal, and it is why the silhouette stays clean while turning.
      if (normal.z <= _minimumFacing) continue;

      final corners = <Vec3>[
        transformPoint(
          surfacePoint(spec, lonStart, latStart, options: options),
        ),
        transformPoint(surfacePoint(spec, lonEnd, latStart, options: options)),
        transformPoint(surfacePoint(spec, lonEnd, latEnd, options: options)),
        transformPoint(surfacePoint(spec, lonStart, latEnd, options: options)),
      ];

      final path = ui.Path();
      for (var index = 0; index < corners.length; index++) {
        final projected = project(corners[index]);
        if (index == 0) {
          path.moveTo(projected.x, projected.y);
        } else {
          path.lineTo(projected.x, projected.y);
        }
      }
      path.close();

      final shade = clampDouble(
        normal.x * light.x + normal.y * light.y + normal.z * light.z,
        -1,
        1,
      );
      final depth =
          corners.fold<double>(0, (sum, point) => sum + point.z) /
          corners.length;

      depthSum += depth;
      depthCount++;
      cells.add(SurfaceCell(path, shade, depth));
    }
  }

  cells.sort((left, right) => left.depth.compareTo(right.depth));

  // The silhouette comes from the hull of a denser ring sampling, which is
  // both smoother and cheaper than unioning every cell.
  final silhouettePoints = <Vec2>[];
  for (var latIndex = 0; latIndex <= _outlineLatitudeSteps; latIndex++) {
    final latitude = -math.pi / 2 + latIndex / _outlineLatitudeSteps * math.pi;
    for (var lonIndex = 0; lonIndex <= _outlineLongitudeSteps; lonIndex++) {
      final longitude =
          -math.pi + lonIndex / _outlineLongitudeSteps * math.pi * 2;
      silhouettePoints.add(
        project(
          transformPoint(
            surfacePoint(spec, longitude, latitude, options: options),
          ),
        ),
      );
    }
  }

  final hull = convexHull(silhouettePoints);
  final outline = ui.Path();
  if (hull.isNotEmpty) {
    outline.moveTo(hull.first.x, hull.first.y);
    for (final point in hull.skip(1)) {
      outline.lineTo(point.x, point.y);
    }
    outline.close();
  }

  return PartGeometry(
    part: part,
    cells: cells,
    outline: outline,
    depth: depthCount == 0 ? 0 : depthSum / depthCount,
  );
}

List<Vec2> _ellipseBoundary(
  double centerX,
  double centerY,
  double width,
  double height,
  double rotation,
) {
  return List<Vec2>.generate(_ellipseSteps, (index) {
    final angle = index / _ellipseSteps * math.pi * 2;
    return rotateFacePoint(
      Vec2(
        centerX + math.cos(angle) * width / 2,
        centerY + math.sin(angle) * height / 2,
      ),
      centerX,
      centerY,
      rotation,
    );
  });
}

List<Vec2> _roundedRectBoundary(
  double centerX,
  double centerY,
  double width,
  double height,
  double rotation,
  double roundness,
) {
  final halfWidth = width / 2;
  final halfHeight = height / 2;
  final cornerRadius =
      math.min(halfWidth, halfHeight) * clampDouble(roundness / 100, 0, 1);

  if (cornerRadius <= 0.001) {
    final corners = <Vec2>[
      Vec2(centerX - halfWidth, centerY - halfHeight),
      Vec2(centerX + halfWidth, centerY - halfHeight),
      Vec2(centerX + halfWidth, centerY + halfHeight),
      Vec2(centerX - halfWidth, centerY + halfHeight),
    ];
    final points = <Vec2>[];
    for (var edge = 0; edge < corners.length; edge++) {
      final start = corners[edge];
      final end = corners[(edge + 1) % corners.length];
      for (var step = 0; step < _faceEdgeSteps; step++) {
        final progress = step / _faceEdgeSteps;
        points.add(
          rotateFacePoint(
            Vec2(
              interpolate(start.x, end.x, progress),
              interpolate(start.y, end.y, progress),
            ),
            centerX,
            centerY,
            rotation,
          ),
        );
      }
    }
    return points;
  }

  // A stadium/rounded rectangle traced as four arcs joined by four edges.
  final points = <Vec2>[];
  final insetX = halfWidth - cornerRadius;
  final insetY = halfHeight - cornerRadius;
  const arcSteps = 8;
  final corners = <List<double>>[
    <double>[insetX, insetY, 0],
    <double>[-insetX, insetY, math.pi / 2],
    <double>[-insetX, -insetY, math.pi],
    <double>[insetX, -insetY, math.pi * 3 / 2],
  ];

  for (final corner in corners) {
    final cx = corner[0];
    final cy = corner[1];
    final startAngle = corner[2];
    for (var step = 0; step <= arcSteps; step++) {
      final angle = startAngle + step / arcSteps * (math.pi / 2);
      points.add(
        rotateFacePoint(
          Vec2(
            centerX + cx + math.cos(angle) * cornerRadius,
            centerY + cy + math.sin(angle) * cornerRadius,
          ),
          centerX,
          centerY,
          rotation,
        ),
      );
    }
  }
  return points;
}

/// A smile: a constant-thickness stroke along a parabola, with rounded ends.
///
/// Ported from the editor, which sweeps the stroke along the curve's normal and
/// sizes the arc from the mouth's *width*. The earlier version offset the edges
/// vertically and sized the arc from the height, so a tall mouth collapsed into
/// a sharp black V instead of a smile.
List<Vec2> _mouthBoundary(
  double centerX,
  double centerY,
  double width,
  double height,
  double curve,
  double rotation,
) {
  const steps = 28;
  const capSteps = 8;
  final halfWidth = width / 2;
  final halfHeight = height / 2;
  final depth = clampDouble(curve, -100, 100) / 100 * width * 0.28;

  final centers = <Vec2>[];
  final normals = <Vec2>[];
  final tangents = <Vec2>[];
  for (var step = 0; step <= steps; step++) {
    final x = -halfWidth + width * step / steps;
    final nx = x / halfWidth;
    final y = depth * (1 - nx * nx);
    final slope = -2 * depth * x / (halfWidth * halfWidth);
    final length = math.sqrt(1 + slope * slope);
    centers.add(Vec2(centerX + x, centerY + y));
    normals.add(Vec2(-slope / length, 1 / length));
    tangents.add(Vec2(1 / length, slope / length));
  }

  Vec2 capPoint(int i, double angle) => Vec2(
    centers[i].x +
        (math.cos(angle) * tangents[i].x + math.sin(angle) * normals[i].x) *
            halfHeight,
    centers[i].y +
        (math.cos(angle) * tangents[i].y + math.sin(angle) * normals[i].y) *
            halfHeight,
  );

  final points = <Vec2>[
    for (var i = 0; i <= steps; i++)
      Vec2(
        centers[i].x - normals[i].x * halfHeight,
        centers[i].y - normals[i].y * halfHeight,
      ),
    for (var i = 1; i <= capSteps; i++)
      capPoint(steps, -math.pi / 2 + i / capSteps * math.pi),
    for (var i = steps - 1; i >= 0; i--)
      Vec2(
        centers[i].x + normals[i].x * halfHeight,
        centers[i].y + normals[i].y * halfHeight,
      ),
    for (var i = 1; i < capSteps; i++)
      capPoint(0, math.pi / 2 + i / capSteps * math.pi),
  ];

  return <Vec2>[
    for (final point in points)
      rotateFacePoint(point, centerX, centerY, rotation),
  ];
}

/// An open mouth: flat along the top, rounded below, like a happy "D".
///
/// [curve] lifts the corners a little, so it can read as a grin or a gasp.
List<Vec2> _openMouthBoundary(
  double centerX,
  double centerY,
  double width,
  double height,
  double curve,
  double rotation,
) {
  const steps = 24;
  final top = centerY - height / 2;
  final lift = clampDouble(curve, -100, 100) / 100 * height * 0.25;
  final points = <Vec2>[];
  for (var step = 0; step <= steps; step++) {
    final angle = math.pi * step / steps;
    points.add(
      Vec2(
        centerX + math.cos(angle) * width / 2,
        top + math.sin(angle) * height,
      ),
    );
  }
  // The top edge, from the left corner back to the right. Sagging in the
  // middle lifts the corners, so it reads as a smile rather than a flat lid.
  for (var step = 1; step < steps; step++) {
    final x = centerX - width / 2 + width * step / steps;
    final nx = (x - centerX) / (width / 2);
    points.add(Vec2(x, top + lift * (1 - nx * nx)));
  }
  return <Vec2>[
    for (final point in points)
      rotateFacePoint(point, centerX, centerY, rotation),
  ];
}

FaceGeometry _buildFace(
  AvatarPart part,
  AvatarFaceStyle style,
  AvatarViewState view,
) {
  final spec = kShapeSpecs[part.shape]!;
  final options = part.shapeOptions;

  Vec3 transformPoint(Vec3 point) {
    final scaled = Vec3(
      point.x * part.scaleX,
      point.y * part.scaleY,
      point.z * part.scaleZ,
    );
    final rotated = rotateLocal(
      scaled,
      rotationX: part.rotationX,
      rotationY: part.rotationY,
      rotationZ: part.rotationZ,
    );
    return rotateByPose(
      Vec3(rotated.x + part.x, rotated.y + part.y, rotated.z + part.z),
      view.yaw,
      view.pitch,
    );
  }

  Vec3 transformNormal(Vec3 normal) {
    final scaled = normalize(
      Vec3(
        normal.x / part.scaleX,
        normal.y / part.scaleY,
        normal.z / part.scaleZ,
      ),
    );
    final rotated = rotateLocal(
      scaled,
      rotationX: part.rotationX,
      rotationY: part.rotationY,
      rotationZ: part.rotationZ,
    );
    return rotateByPose(rotated, view.yaw, view.pitch);
  }

  /// Lifts a face outline onto the head and drops it if it has turned away.
  FaceFeature? projectFeature(
    double centerX,
    double centerY,
    List<Vec2> boundary,
  ) {
    final centerNormal = transformNormal(
      faceNormal(spec, Vec2(centerX, centerY), options: options),
    );

    final lifted = boundary
        .map(
          (point) => transformPoint(facePoint(spec, point, options: options)),
        )
        .toList(growable: false);
    final visible = clipToVisibleHemisphere(lifted);
    if (visible.length < 3) return null;

    final path = ui.Path();
    for (var index = 0; index < visible.length; index++) {
      final projected = project(visible[index]);
      if (index == 0) {
        path.moveTo(projected.x, projected.y);
      } else {
        path.lineTo(projected.x, projected.y);
      }
    }
    path.close();

    return FaceFeature(path, clampDouble(centerNormal.z, 0, 1));
  }

  final eyeOffset = style.gap / 2 + style.width / 2;
  final eyes = <FaceFeature>[];
  final highlights = <FaceFeature>[];

  for (var index = 0; index < 2; index++) {
    final centerX = index == 0 ? -eyeOffset : eyeOffset;
    const centerY = 0.0;
    final rotation =
        style.rotation +
        (index == 0 ? style.leftEyeRotation : style.rightEyeRotation);

    final boundary = style.eyeShape == 'ellipse'
        ? _ellipseBoundary(
            centerX,
            centerY,
            style.width,
            style.height,
            rotation,
          )
        : _roundedRectBoundary(
            centerX,
            centerY,
            style.width,
            style.height,
            rotation,
            style.eyeRoundness,
          );

    final eye = projectFeature(centerX, centerY, boundary);
    if (eye == null) continue;
    eyes.add(eye);

    if (!style.highlightEnabled) continue;
    final rawCenter = Vec2(
      centerX + style.width * style.highlightOffsetX / 100,
      centerY + style.height * style.highlightOffsetY / 100,
    );
    final center = rotateFacePoint(rawCenter, centerX, centerY, rotation);
    final diameter = math.max(
      math.min(style.width, style.height) * style.highlightSize / 100,
      1.0,
    );
    final highlight = projectFeature(
      center.x,
      center.y,
      _ellipseBoundary(center.x, center.y, diameter, diameter, rotation),
    );
    if (highlight != null) highlights.add(highlight);
  }

  FaceFeature? nose;
  if (style.noseEnabled) {
    nose = projectFeature(
      0,
      style.noseY,
      _ellipseBoundary(
        0,
        style.noseY,
        style.noseWidth,
        style.noseHeight,
        style.noseRotation,
      ),
    );
  }

  FaceFeature? mouth;
  if (style.mouthEnabled) {
    // An open mouth is a shape, not a stroke. Drawing surprise as a thick
    // curved band reads as a smear across the chin; an ellipse reads as a
    // mouth that is open.
    final boundary = style.mouthShape == 'ellipse'
        ? _ellipseBoundary(
            0,
            style.mouthY,
            style.mouthWidth,
            style.mouthHeight,
            style.mouthRotation,
          )
        : style.mouthShape == 'open'
        ? _openMouthBoundary(
            0,
            style.mouthY,
            style.mouthWidth,
            style.mouthHeight,
            style.mouthCurve,
            style.mouthRotation,
          )
        : _mouthBoundary(
            0,
            style.mouthY,
            style.mouthWidth,
            style.mouthHeight,
            style.mouthCurve,
            style.mouthRotation,
          );
    mouth = projectFeature(0, style.mouthY, boundary);
  }

  return FaceGeometry(
    eyes: eyes,
    highlights: highlights,
    nose: nose,
    mouth: mouth,
  );
}
