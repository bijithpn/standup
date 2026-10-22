import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:breakmate/features/companion/engine/geometry/avatar_body_shapes.dart';
import 'package:breakmate/features/companion/engine/geometry/vec3.dart';

class BodyCell3D {
  final String id;
  final double depth;
  final double shade; // -1.0 (shadow) to +1.0 (highlight)
  final List<ui.Offset> vertices;
  final List<Vec3> worldVertices;

  const BodyCell3D({
    required this.id,
    required this.depth,
    required this.shade,
    required this.vertices,
    required this.worldVertices,
  });
}

class BodyTriangle3D {
  final String id;
  final double depth;
  final List<Vec3> vertices;
  final List<ui.Offset> projectedVertices;

  const BodyTriangle3D({
    required this.id,
    required this.depth,
    required this.vertices,
    required this.projectedVertices,
  });
}

/// Native Dart port of OneWorks 3D geometric body compiler (`avatarGeometry.ts`)
class Avatar3DGeometry {
  final List<BodyCell3D> cells;
  final List<ui.Offset> outlinePoints;
  final List<BodyTriangle3D> depthSortedTriangles;
  final ui.Rect bounds;

  const Avatar3DGeometry({
    required this.cells,
    required this.outlinePoints,
    required this.depthSortedTriangles,
    required this.bounds,
  });

  static double _signedPow(double baseVal, double exp) {
    if (baseVal == 0.0) return 0.0;
    final sign = baseVal < 0 ? -1.0 : 1.0;
    return sign * math.pow(baseVal.abs(), exp);
  }

  static double _clamp(double val, double min, double max) {
    return math.max(min, math.min(max, val));
  }

  /// Evaluates 3D surface point on superellipsoid / quadric / cone profile
  static Vec3 _getSurfacePoint(
    AvatarShapeSpec spec,
    double longitude,
    double latitude, {
    double scaleX = 1.0,
    double scaleY = 1.0,
    double scaleZ = 1.0,
    double roundness = 24.0,
    double cutAngle = 0.0,
    double bottomTaper = 0.0,
  }) {
    if (spec.profile == 'cone' ||
        spec.profile == 'frustum' ||
        spec.profile == 'half-cone') {
      final progress = _clamp((math.sin(latitude) + 1.0) / 2.0, 0.0, 1.0);
      final rClamped = _clamp(roundness, 0.0, 100.0) / 100.0;
      final easedProgress = progress * progress * (3.0 - 2.0 * progress);
      final taperedProgress = spec.profile == 'frustum'
          ? (progress + (easedProgress - progress) * rClamped * 0.55)
          : math.pow(progress, 1.0 + (0.56 - 1.0) * rClamped).toDouble();

      final tipRatio = spec.profile == 'frustum' ? 0.46 : 0.0;
      final ringRadius = tipRatio + (1.0 - tipRatio) * taperedProgress;
      final cutAngleRad = cutAngle * math.pi / 180.0;
      final sampledLon = spec.profile == 'half-cone'
          ? cutAngleRad + longitude / 2.0
          : longitude;

      return Vec3(
        spec.radiusX * scaleX * ringRadius * math.sin(sampledLon),
        spec.radiusY * scaleY * (progress * 2.0 - 1.0),
        spec.radiusZ * scaleZ * ringRadius * math.cos(sampledLon),
      );
    }

    final cosLat = math.max(math.cos(latitude), 0.0);
    final latFactor = math.pow(cosLat, spec.exponent).toDouble();
    final vertical = _signedPow(math.sin(latitude), spec.exponent);

    // Bottom taper calculation
    double lowerTaper = 1.0;
    if (bottomTaper != 0.0 && vertical < 0.0) {
      final t = _clamp(-vertical, 0.0, 1.0);
      lowerTaper = 1.0 - (bottomTaper / 100.0) * t * 0.5;
    }

    return Vec3(
      spec.radiusX *
          scaleX *
          latFactor *
          lowerTaper *
          _signedPow(math.sin(longitude), spec.exponent),
      spec.radiusY * scaleY * vertical,
      spec.radiusZ *
          scaleZ *
          latFactor *
          lowerTaper *
          _signedPow(math.cos(longitude), spec.exponent),
    );
  }

  /// Calculates surface normal via finite difference tangents
  static Vec3 _getSurfaceNormal(
    AvatarShapeSpec spec,
    double longitude,
    double latitude, {
    double scaleX = 1.0,
    double scaleY = 1.0,
    double scaleZ = 1.0,
    double roundness = 24.0,
    double cutAngle = 0.0,
    double bottomTaper = 0.0,
  }) {
    const delta = 0.008;
    final center = _getSurfacePoint(
      spec,
      longitude,
      latitude,
      scaleX: scaleX,
      scaleY: scaleY,
      scaleZ: scaleZ,
      roundness: roundness,
      cutAngle: cutAngle,
      bottomTaper: bottomTaper,
    );
    final pLon = _getSurfacePoint(
      spec,
      longitude + delta,
      latitude,
      scaleX: scaleX,
      scaleY: scaleY,
      scaleZ: scaleZ,
      roundness: roundness,
      cutAngle: cutAngle,
      bottomTaper: bottomTaper,
    );
    final pLat = _getSurfacePoint(
      spec,
      longitude,
      latitude + delta,
      scaleX: scaleX,
      scaleY: scaleY,
      scaleZ: scaleZ,
      roundness: roundness,
      cutAngle: cutAngle,
      bottomTaper: bottomTaper,
    );

    final tangentLon = pLon - center;
    final tangentLat = pLat - center;
    return tangentLon.cross(tangentLat).normalized();
  }

  /// Compiles authentic 3D geometry with 3D transformations, normals, Lambertian shading, and depth
  static Avatar3DGeometry buildBodyGeometry({
    required AvatarBodyShape shape,
    required double yaw,
    required double pitch,
    required double roll,
    double lightAzimuth = 45.0,
    double lightElevation = 30.0,
    int gridDensity = 100,
    double scaleX = 1.0,
    double scaleY = 1.0,
    double scaleZ = 1.0,
    double roundness = 24.0,
    double cutAngle = 0.0,
    double bottomTaper = 0.0,
    ui.Offset centerOffset = const ui.Offset(210, 202),
  }) {
    final spec =
        AvatarShapeSpec.specs[shape] ??
        AvatarShapeSpec.specs[AvatarBodyShape.sphere]!;

    // Transform in 3D: Local -> Rotate yaw, pitch, roll
    Vec3 transform3D(Vec3 point) {
      var p = point;
      if (yaw != 0.0) p = p.rotateY(yaw);
      if (pitch != 0.0) p = p.rotateX(pitch);
      if (roll != 0.0) p = p.rotateZ(roll);
      return p;
    }

    // Light directional unit vector in camera space
    final azRad = lightAzimuth * math.pi / 180.0;
    final elRad = lightElevation * math.pi / 180.0;
    final lightVec = Vec3(
      math.cos(elRad) * math.sin(azRad),
      -math.sin(elRad),
      math.cos(elRad) * math.cos(azRad),
    ).normalized();

    final densityScale = _clamp(gridDensity / 100.0, 0.25, 4.0);
    final latSteps = math.max(6, (14 * densityScale).round());
    final lonSteps = math.max(12, (28 * densityScale).round());

    final cells = <BodyCell3D>[];
    final outlinePoints = <ui.Offset>[];
    final triangles = <BodyTriangle3D>[];

    ui.Offset project(Vec3 v) {
      return ui.Offset(centerOffset.dx + v.x, centerOffset.dy + v.y);
    }

    // 1. Compile 3D outline vertices
    const outlineLatSteps = 24;
    const outlineLonSteps = 48;
    for (int i = 0; i <= outlineLatSteps; i++) {
      final lat = -math.pi / 2 + (i / outlineLatSteps) * math.pi;
      for (int j = 0; j <= outlineLonSteps; j++) {
        final lon = -math.pi + (j / outlineLonSteps) * math.pi * 2;
        final rawPoint = _getSurfacePoint(
          spec,
          lon,
          lat,
          scaleX: scaleX,
          scaleY: scaleY,
          scaleZ: scaleZ,
          roundness: roundness,
          cutAngle: cutAngle,
          bottomTaper: bottomTaper,
        );
        final worldP = transform3D(rawPoint);
        outlinePoints.add(project(worldP));
      }
    }

    // 2. Compile shaded 3D cells
    for (int latIdx = 0; latIdx < latSteps; latIdx++) {
      final lat0 = -math.pi / 2 + (latIdx / latSteps) * math.pi;
      final lat1 = -math.pi / 2 + ((latIdx + 1) / latSteps) * math.pi;

      for (int lonIdx = 0; lonIdx < lonSteps; lonIdx++) {
        final lon0 = -math.pi + (lonIdx / lonSteps) * math.pi * 2;
        final lon1 = -math.pi + ((lonIdx + 1) / lonSteps) * math.pi * 2;

        final rawNormal = _getSurfaceNormal(
          spec,
          (lon0 + lon1) / 2,
          (lat0 + lat1) / 2,
          scaleX: scaleX,
          scaleY: scaleY,
          scaleZ: scaleZ,
          roundness: roundness,
          cutAngle: cutAngle,
          bottomTaper: bottomTaper,
        );
        final worldNormal = transform3D(rawNormal);

        // Horizon back-face culling for cells
        if (worldNormal.z <= 0.015) continue;

        final p00 = transform3D(
          _getSurfacePoint(
            spec,
            lon0,
            lat0,
            scaleX: scaleX,
            scaleY: scaleY,
            scaleZ: scaleZ,
          ),
        );
        final p10 = transform3D(
          _getSurfacePoint(
            spec,
            lon1,
            lat0,
            scaleX: scaleX,
            scaleY: scaleY,
            scaleZ: scaleZ,
          ),
        );
        final p11 = transform3D(
          _getSurfacePoint(
            spec,
            lon1,
            lat1,
            scaleX: scaleX,
            scaleY: scaleY,
            scaleZ: scaleZ,
          ),
        );
        final p01 = transform3D(
          _getSurfacePoint(
            spec,
            lon0,
            lat1,
            scaleX: scaleX,
            scaleY: scaleY,
            scaleZ: scaleZ,
          ),
        );

        final avgDepth = (p00.z + p10.z + p11.z + p01.z) / 4.0;
        final shade = _clamp(worldNormal.dot(lightVec), -1.0, 1.0);

        final projectedCorners = [
          project(p00),
          project(p10),
          project(p11),
          project(p01),
        ];

        cells.add(
          BodyCell3D(
            id: '$latIdx-$lonIdx',
            depth: avgDepth,
            shade: shade,
            vertices: projectedCorners,
            worldVertices: [p00, p10, p11, p01],
          ),
        );

        // Depth-sorted triangles
        triangles.add(
          BodyTriangle3D(
            id: '$latIdx-$lonIdx-a',
            depth: (p00.z + p10.z + p11.z) / 3.0,
            vertices: [p00, p10, p11],
            projectedVertices: [project(p00), project(p10), project(p11)],
          ),
        );
        triangles.add(
          BodyTriangle3D(
            id: '$latIdx-$lonIdx-b',
            depth: (p00.z + p11.z + p01.z) / 3.0,
            vertices: [p00, p11, p01],
            projectedVertices: [project(p00), project(p11), project(p01)],
          ),
        );
      }
    }

    // Sort cells back-to-front by depth (lowest Z to highest Z)
    cells.sort((a, b) => a.depth.compareTo(b.depth));
    triangles.sort((a, b) => a.depth.compareTo(b.depth));

    // Convex hull calculation for outline
    final hull = _computeConvexHull(outlinePoints);

    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in hull) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    return Avatar3DGeometry(
      cells: cells,
      outlinePoints: hull,
      depthSortedTriangles: triangles,
      bounds: ui.Rect.fromLTRB(minX, minY, maxX, maxY),
    );
  }

  static List<ui.Offset> _computeConvexHull(List<ui.Offset> points) {
    if (points.length <= 3) return points;
    final sorted = List<ui.Offset>.from(points)
      ..sort(
        (a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy),
      );

    double crossProduct(ui.Offset o, ui.Offset a, ui.Offset b) {
      return (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    }

    final lower = <ui.Offset>[];
    for (final p in sorted) {
      while (lower.length >= 2 &&
          crossProduct(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }

    final upper = <ui.Offset>[];
    for (final p in sorted.reversed) {
      while (upper.length >= 2 &&
          crossProduct(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }

    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }
}
