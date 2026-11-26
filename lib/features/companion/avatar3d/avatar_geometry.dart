import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:breakmate/features/companion/avatar3d/avatar_math.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_shape.dart';

class SurfaceCell {
  const SurfaceCell(this.shade, this.depth);

  final double shade;
  final double depth;
}

class PartGeometry {
  const PartGeometry({
    required this.part,
    required this.cells,
    required this.mesh,
    required this.outline,
    required this.depth,
  });

  final AvatarPart part;
  final List<SurfaceCell> cells;

  /// Gouraud-shaded visible surface: shared grid vertices, one colour each, indexed back to front.
  final ui.Vertices? mesh;

  final ui.Path outline;

  final double depth;
}

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

/// Projected 2D output of the 3D scene: per-part outlines/surface cells, face features, and overall bounds, ready for AvatarScenePainter.
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

  final ui.Rect bounds;
}

const int _baseLatitudeSteps = 20;
const int _baseLongitudeSteps = 40;
const int _ellipseSteps = 40;
const int _faceEdgeSteps = 8;
// Cells facing away from the camera below this threshold are culled.
const double _minimumFacing = 0.015;

/// Rotates each part by view yaw/pitch, tessellates its surface, culls back-facing cells and projects to 2D; densityScale trades detail for speed.
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
      scene.lightDistance,
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
  Vec3 light,
  double lightDistance, {
  required int latitudeSteps,
  required int longitudeSteps,
}) {
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
    final placed = Vec3(
      rotated.x + part.x,
      rotated.y + part.y,
      rotated.z + part.z,
    );
    return rotateByPose(placed, view.yaw, view.pitch);
  }

  final stride = longitudeSteps + 1;
  final count = (latitudeSteps + 1) * stride;
  final points = List<Vec3>.filled(count, const Vec3(0, 0, 0));
  final normals = List<Vec3>.filled(count, const Vec3(0, 0, 0));
  final positions = Float32List(count * 2);
  final colors = Int32List(count);
  final projected = <Vec2>[];

  for (var lat = 0; lat <= latitudeSteps; lat++) {
    final latitude = -math.pi / 2 + lat / latitudeSteps * math.pi;
    for (var lon = 0; lon <= longitudeSteps; lon++) {
      final longitude = -math.pi + lon / longitudeSteps * math.pi * 2;
      final i = lat * stride + lon;
      final point = transformPoint(
        surfacePoint(spec, longitude, latitude, options: options),
      );
      points[i] = point;
      final flat = project(point);
      projected.add(flat);
      positions[i * 2] = flat.x;
      positions[i * 2 + 1] = flat.y;
    }
  }

  // Central differences on the grid itself: one surface sample per vertex instead of four.
  for (var lat = 1; lat < latitudeSteps; lat++) {
    for (var lon = 0; lon <= longitudeSteps; lon++) {
      final i = lat * stride + lon;
      final west = lon == 0 ? i + longitudeSteps - 1 : i - 1;
      final east = lon == longitudeSteps ? i - longitudeSteps + 1 : i + 1;
      normals[i] = normalize(
        cross(
          subtract(points[east], points[west]),
          subtract(points[i + stride], points[i - stride]),
        ),
      );
    }
  }
  for (final (pole, ring) in [(0, 1), (latitudeSteps, latitudeSteps - 1)]) {
    var sum = const Vec3(0, 0, 0);
    for (var lon = 0; lon < longitudeSteps; lon++) {
      final n = normals[ring * stride + lon];
      sum = Vec3(sum.x + n.x, sum.y + n.y, sum.z + n.z);
    }
    final n = normalize(sum);
    for (var lon = 0; lon <= longitudeSteps; lon++) {
      normals[pole * stride + lon] = n;
    }
  }
  for (var i = 0; i < count; i++) {
    final normal = normals[i];
    final shade = clampDouble(
      normal.x * light.x + normal.y * light.y + normal.z * light.z,
      -1,
      1,
    );
    final tint = shade >= 0 ? part.highlightColor : part.shadowColor;
    colors[i] = ui.Color.lerp(
      part.baseColor,
      tint,
      surfaceShadeOpacity(shade, lightDistance).clamp(0.0, 1.0),
    )!.toARGB32();
  }
  final cells = <SurfaceCell>[];
  final order = <int>[];
  final depths = List<double>.filled(count, 0);
  var depthSum = 0.0;
  for (var lat = 0; lat < latitudeSteps; lat++) {
    for (var lon = 0; lon < longitudeSteps; lon++) {
      final a = lat * stride + lon;
      final n0 = normals[a], n1 = normals[a + 1];
      final n2 = normals[a + stride + 1], n3 = normals[a + stride];
      if (n0.z + n1.z + n2.z + n3.z <= 4 * _minimumFacing) continue;
      final shade = clampDouble(
        ((n0.x + n1.x + n2.x + n3.x) * light.x +
                (n0.y + n1.y + n2.y + n3.y) * light.y +
                (n0.z + n1.z + n2.z + n3.z) * light.z) /
            4,
        -1,
        1,
      );
      final depth =
          (points[a].z +
              points[a + 1].z +
              points[a + stride + 1].z +
              points[a + stride].z) /
          4;
      depths[a] = depth;
      depthSum += depth;
      order.add(a);
      cells.add(SurfaceCell(shade, depth));
    }
  }
  order.sort((l, r) => depths[l].compareTo(depths[r]));
  cells.sort((l, r) => l.depth.compareTo(r.depth));

  final indices = Uint16List(order.length * 6);
  for (var k = 0; k < order.length; k++) {
    final a = order[k];
    final at = k * 6;
    indices[at] = a;
    indices[at + 1] = a + 1;
    indices[at + 2] = a + stride + 1;
    indices[at + 3] = a;
    indices[at + 4] = a + stride + 1;
    indices[at + 5] = a + stride;
  }

  final hull = convexHull(projected);
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
    mesh: cells.isEmpty
        ? null
        : ui.Vertices.raw(
            ui.VertexMode.triangles,
            positions,
            colors: colors,
            indices: indices,
          ),
    outline: outline,
    depth: cells.isEmpty ? 0 : depthSum / cells.length,
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
