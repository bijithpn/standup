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
    this.positions,
    this.vertexColors,
    this.vertexDepths,
    this.indices,
  });

  final Float32List? positions;
  final Int32List? vertexColors;
  final Float32List? vertexDepths;
  final Uint16List? indices;
  final AvatarPart part;
  final List<SurfaceCell> cells;

  /// Gouraud-shaded visible surface: shared grid vertices, one colour each, indexed back to front.
  final ui.Vertices? mesh;

  final ui.Path outline;

  final double depth;
}

class FaceFeature {
  const FaceFeature(this.path, this.depth, [this.vertices = const []]);

  final ui.Path path;
  final double depth;
  final List<Vec3> vertices;
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
    this.visibleRegions = const {},
  });

  final Map<String, ui.Path> visibleRegions;
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

/// Bounded shared cache of part-local surfaces. Pose, lighting and palette never
/// enter the key; instances reuse authored geometry across animation frames.
final _surfaceCache = <String, List<Vec3>>{};
const _surfaceCacheLimit = 128;

List<Vec3> _surfaceGrid(AvatarPart part, int latitudes, int longitudes) {
  final key =
      '${part.shape}:${part.roundness}:${part.topScale}:'
      '${part.bottomTaper}:${part.cutAngle}:${part.muzzleProjection}:'
      '${part.muzzleWidth}:${part.muzzleY}:${part.jawTaper}:$latitudes:$longitudes';
  final cached = _surfaceCache.remove(key);
  if (cached != null) {
    _surfaceCache[key] = cached;
    return cached;
  }
  final spec = kShapeSpecs[part.shape]!;
  final options = part.shapeOptions;
  final grid = List<Vec3>.generate(
    (latitudes + 1) * (longitudes + 1),
    (i) => surfacePoint(
      spec,
      -math.pi + (i % (longitudes + 1)) / longitudes * math.pi * 2,
      -math.pi / 2 + (i ~/ (longitudes + 1)) / latitudes * math.pi,
      options: options,
    ),
    growable: false,
  );
  if (_surfaceCache.length >= _surfaceCacheLimit) {
    _surfaceCache.remove(_surfaceCache.keys.first);
  }
  _surfaceCache[key] = grid;
  return grid;
}

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
      matte: scene.matte,
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
    visibleRegions: scene.faceStyle.eyeShape.startsWith('reference-')
        ? _resolveVisibleRegions(parts, bounds, densityScale)
        : const {},
  );
}

PartGeometry _buildPart(
  AvatarPart part,
  AvatarViewState view,
  Vec3 light,
  double lightDistance, {
  required int latitudeSteps,
  required int longitudeSteps,
  bool matte = false,
}) {
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
  final vertexDepths = Float32List(count);
  final colors = Int32List(count);
  final projected = <Vec2>[];
  final localPoints = _surfaceGrid(part, latitudeSteps, longitudeSteps);

  for (var lat = 0; lat <= latitudeSteps; lat++) {
    for (var lon = 0; lon <= longitudeSteps; lon++) {
      final i = lat * stride + lon;
      final local = localPoints[i];
      final point = transformPoint(local);
      points[i] = point;
      vertexDepths[i] = point.z;
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
    if (matte) {
      colors[i] = part.baseColor.toARGB32();
      continue;
    }
    final normal = normals[i];
    final shade = clampDouble(
      normal.x * light.x + normal.y * light.y + normal.z * light.z,
      -1,
      1,
    );
    final local = localPoints[i];
    final muzzleWeight = part.muzzleColor == null || local.z < 0
        ? 0.0
        : (1 -
                  (math.pow(local.x / (part.muzzleWidth * 1.12), 4) +
                          math.pow((local.y - part.muzzleY - 12) / 43, 4))
                      .toDouble())
              .clamp(0.0, 1.0);
    final base = ui.Color.lerp(
      part.baseColor,
      part.muzzleColor ?? part.baseColor,
      muzzleWeight,
    )!;
    final tint = shade >= 0
        ? ui.Color.lerp(base, part.highlightColor, .65)!
        : part.shadowColor;
    colors[i] = ui.Color.lerp(
      base,
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

  ui.Vertices? matteMesh;
  if (matte && order.isNotEmpty) {
    final flatIndices = Uint16List(order.length * 6);
    // Four corners per cell, shared by its two triangles; a single flat tone.
    final cellPositions = Float32List(order.length * 8);
    final cellColors = Int32List(order.length * 4);
    for (var k = 0; k < order.length; k++) {
      final a = order[k];
      final ns = [
        normals[a],
        normals[a + 1],
        normals[a + stride + 1],
        normals[a + stride],
      ];
      final shade =
          ns.fold<double>(
            0,
            (v, n) => v + n.x * light.x + n.y * light.y + n.z * light.z,
          ) /
          4;
      final band = (shade * 4).round() / 4;
      final tint = band >= 0 ? part.highlightColor : part.shadowColor;
      final strength = (band >= 0 ? .055 : .19) * band.abs();
      final color = ui.Color.lerp(part.baseColor, tint, strength)!.toARGB32();
      final vertices = [a, a + 1, a + stride + 1, a + stride];
      for (var j = 0; j < 4; j++) {
        cellPositions[(k * 4 + j) * 2] = positions[vertices[j] * 2];
        cellPositions[(k * 4 + j) * 2 + 1] = positions[vertices[j] * 2 + 1];
        cellColors[k * 4 + j] = color;
      }
      final offset = k * 4, at = k * 6;
      flatIndices.setRange(at, at + 6, [
        offset,
        offset + 1,
        offset + 2,
        offset,
        offset + 2,
        offset + 3,
      ]);
    }
    matteMesh = ui.Vertices.raw(
      ui.VertexMode.triangles,
      cellPositions,
      colors: cellColors,
      indices: flatIndices,
    );
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
    mesh:
        matteMesh ??
        (cells.isEmpty
            ? null
            : ui.Vertices.raw(
                ui.VertexMode.triangles,
                positions,
                colors: colors,
                indices: indices,
              )),
    outline: outline,
    depth: cells.isEmpty ? 0 : depthSum / cells.length,
    positions: positions,
    vertexColors: colors,
    vertexDepths: vertexDepths,
    indices: indices,
  );
}

/// Resolve actual surface ownership with a bounded software depth buffer. The
/// resulting part-local clips let vector eyes and markings retain smooth edges
/// while intersecting cheeks, muzzles and ears occlude each other correctly.
Map<String, ui.Path> _resolveVisibleRegions(
  List<PartGeometry> parts,
  ui.Rect bounds,
  double density,
) {
  final resolution = (density * 280).round().clamp(192, 448);
  final extent = math.max(bounds.width, bounds.height) + 4;
  final step = extent / resolution;
  final origin = ui.Offset(
    bounds.center.dx - extent / 2,
    bounds.center.dy - extent / 2,
  );
  final depth = Float32List(resolution * resolution);
  for (var i = 0; i < depth.length; i++) {
    depth[i] = double.negativeInfinity;
  }
  final owner = Int16List(resolution * resolution);
  owner.fillRange(0, owner.length, -1);
  for (var id = 0; id < parts.length; id++) {
    final xy = parts[id].positions,
        z = parts[id].vertexDepths,
        indices = parts[id].indices;
    if (xy == null || z == null || indices == null) continue;
    for (var i = 0; i < indices.length; i += 3) {
      final a = indices[i], b = indices[i + 1], c = indices[i + 2];
      final ax = (xy[a * 2] - origin.dx) / step,
          ay = (xy[a * 2 + 1] - origin.dy) / step;
      final bx = (xy[b * 2] - origin.dx) / step,
          by = (xy[b * 2 + 1] - origin.dy) / step;
      final cx = (xy[c * 2] - origin.dx) / step,
          cy = (xy[c * 2 + 1] - origin.dy) / step;
      final denominator = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy);
      if (denominator.abs() < 1e-8) continue;
      final left = math
          .min(ax, math.min(bx, cx))
          .floor()
          .clamp(0, resolution - 1);
      final right = math
          .max(ax, math.max(bx, cx))
          .ceil()
          .clamp(0, resolution - 1);
      final top = math
          .min(ay, math.min(by, cy))
          .floor()
          .clamp(0, resolution - 1);
      final bottom = math
          .max(ay, math.max(by, cy))
          .ceil()
          .clamp(0, resolution - 1);
      for (var y = top; y <= bottom; y++) {
        for (var x = left; x <= right; x++) {
          final u =
              ((by - cy) * (x + .5 - cx) + (cx - bx) * (y + .5 - cy)) /
              denominator;
          final v =
              ((cy - ay) * (x + .5 - cx) + (ax - cx) * (y + .5 - cy)) /
              denominator;
          if (u < -.00001 || v < -.00001 || u + v > 1.00001) continue;
          final d = u * z[a] + v * z[b] + (1 - u - v) * z[c];
          final at = y * resolution + x;
          if (d > depth[at]) {
            depth[at] = d;
            owner[at] = id;
          }
        }
      }
    }
  }
  final paths = [for (final _ in parts) ui.Path()];
  // Merge equal runs vertically to avoid thousands of internal clip edges.
  var active = <(int, int, int), ui.Rect>{};
  for (var y = 0; y <= resolution; y++) {
    final next = <(int, int, int), ui.Rect>{};
    if (y < resolution) {
      var x = 0;
      while (x < resolution) {
        final id = owner[y * resolution + x], start = x++;
        while (x < resolution && owner[y * resolution + x] == id) {
          x++;
        }
        if (id < 0) continue;
        final key = (id, start, x), previous = active.remove(key);
        next[key] = ui.Rect.fromLTRB(
          start.toDouble(),
          previous?.top ?? y.toDouble(),
          x.toDouble(),
          y + 1.0,
        );
      }
    }
    for (final entry in active.entries) {
      final r = entry.value;
      paths[entry.key.$1].addRect(
        ui.Rect.fromLTRB(
          origin.dx + r.left * step,
          origin.dy + r.top * step,
          origin.dx + r.right * step,
          origin.dy + r.bottom * step,
        ).inflate(step * .15),
      );
    }
    active = next;
  }
  return {for (var i = 0; i < parts.length; i++) parts[i].part.id: paths[i]};
}

/// Eyelid changes reuse the cached body meshes and ownership masks.
AvatarGeometry updateAvatarFace(AvatarGeometry geometry, AvatarScene scene) =>
    AvatarGeometry(
      parts: geometry.parts,
      facePartId: geometry.facePartId,
      bounds: geometry.bounds,
      visibleRegions: geometry.visibleRegions,
      face: scene.facePart == null
          ? const FaceGeometry(eyes: [], highlights: [])
          : _buildFace(scene.facePart!, scene.faceStyle, scene.viewState),
    );

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

// Rounded inverted-triangle construction adapted from OneWorks avatarGeometry.ts.
// Copyright One Works contributors; see assets/avatars/LICENSE.
List<Vec2> _roundedTriangleBoundary(
  double x,
  double y,
  double w,
  double h,
  double rotation,
) {
  Vec2 p(double a, double b) => Vec2(x + w * a, y + h * b);
  final left = p(-.5, -.18),
      right = p(.5, -.18),
      rt = p(.07, .45),
      lt = p(-.07, .45);
  final points = <Vec2>[left];
  void curve(Vec2 a, Vec2 b, Vec2 c, Vec2 d) {
    for (var i = 1; i <= 12; i++) {
      final t = i / 12, u = 1 - t;
      points.add(
        Vec2(
          u * u * u * a.x +
              3 * u * u * t * b.x +
              3 * u * t * t * c.x +
              t * t * t * d.x,
          u * u * u * a.y +
              3 * u * u * t * b.y +
              3 * u * t * t * c.y +
              t * t * t * d.y,
        ),
      );
    }
  }

  curve(left, p(-.45, -.5), p(.45, -.5), right);
  curve(right, p(.5, .08), p(.18, .42), rt);
  curve(rt, p(.04, .52), p(-.04, .52), lt);
  curve(lt, p(-.18, .42), p(-.5, .08), left);
  return [for (final point in points) rotateFacePoint(point, x, y, rotation)];
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

    return FaceFeature(path, clampDouble(centerNormal.z, 0, 1), visible);
  }

  final eyeOffset = style.gap / 2 + style.width / 2;
  final eyes = <FaceFeature>[];
  final highlights = <FaceFeature>[];

  for (var index = 0; index < 2; index++) {
    final centerX = index == 0 ? -eyeOffset : eyeOffset;
    final centerY = style.eyeOffsetY;
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
      (style.noseShape == 'inverted-triangle'
          ? _roundedTriangleBoundary
          : _ellipseBoundary)(
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
