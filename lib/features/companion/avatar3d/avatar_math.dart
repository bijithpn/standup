import 'dart:math' as math;

/// The vector and projection maths behind the OneWorks avatar scene.
///
/// This is a direct port of `avatarGeometry.ts`. The constants and the order of
/// operations are load-bearing: change them and the companions stop matching
/// the artwork the editor produces, which is the whole point of porting rather
/// than approximating.

/// The authored view box every scene is laid out in.
const double kViewSize = 420;
const double kCenterX = kViewSize / 2;

/// Not the vertical centre — the authored scenes sit slightly high in frame.
const double kCenterY = 202;

class Vec2 {
  const Vec2(this.x, this.y);

  final double x;
  final double y;

  @override
  String toString() => 'Vec2(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

double clampDouble(double value, double min, double max) =>
    value < min ? min : (value > max ? max : value);

double signedPow(double value, double exponent) =>
    (value < 0 ? -1.0 : (value > 0 ? 1.0 : 0.0)) *
    math.pow(value.abs(), exponent).toDouble();

double interpolate(double from, double to, double progress) =>
    from + (to - from) * progress;

Vec3 normalize(Vec3 v) {
  final length = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
  if (length == 0) return const Vec3(0, 0, 0);
  return Vec3(v.x / length, v.y / length, v.z / length);
}

Vec3 subtract(Vec3 left, Vec3 right) =>
    Vec3(left.x - right.x, left.y - right.y, left.z - right.z);

Vec3 cross(Vec3 left, Vec3 right) => Vec3(
      left.y * right.z - left.z * right.y,
      left.z * right.x - left.x * right.z,
      left.x * right.y - left.y * right.x,
    );

/// The camera rotation: yaw about the vertical axis, then pitch.
Vec3 rotateByPose(Vec3 point, double yaw, double pitch) {
  final cosYaw = math.cos(yaw);
  final sinYaw = math.sin(yaw);
  final yawX = point.x * cosYaw + point.z * sinYaw;
  final yawZ = -point.x * sinYaw + point.z * cosYaw;
  final cosPitch = math.cos(pitch);
  final sinPitch = math.sin(pitch);

  return Vec3(
    yawX,
    point.y * cosPitch + yawZ * sinPitch,
    -point.y * sinPitch + yawZ * cosPitch,
  );
}

/// A part's own rotation, applied before the camera's.
Vec3 rotateLocal(
  Vec3 point, {
  required double rotationX,
  required double rotationY,
  required double rotationZ,
}) {
  final rx = rotationX * math.pi / 180;
  final ry = rotationY * math.pi / 180;
  final rz = rotationZ * math.pi / 180;

  final cosX = math.cos(rx);
  final sinX = math.sin(rx);
  final afterX = Vec3(
    point.x,
    point.y * cosX - point.z * sinX,
    point.y * sinX + point.z * cosX,
  );

  final cosY = math.cos(ry);
  final sinY = math.sin(ry);
  final afterY = Vec3(
    afterX.x * cosY + afterX.z * sinY,
    afterX.y,
    -afterX.x * sinY + afterX.z * cosY,
  );

  final cosZ = math.cos(rz);
  final sinZ = math.sin(rz);
  return Vec3(
    afterY.x * cosZ - afterY.y * sinZ,
    afterY.x * sinZ + afterY.y * cosZ,
    afterY.z,
  );
}

/// Orthographic projection — depth is carried separately, for sorting and
/// shading, rather than being divided out.
Vec2 project(Vec3 point) => Vec2(kCenterX + point.x, kCenterY + point.y);

Vec2 rotateFacePoint(
  Vec2 point,
  double centerX,
  double centerY,
  double rotationDegrees,
) {
  final rotation = rotationDegrees * math.pi / 180;
  final cosR = math.cos(rotation);
  final sinR = math.sin(rotation);
  final localX = point.x - centerX;
  final localY = point.y - centerY;
  return Vec2(
    centerX + localX * cosR - localY * sinR,
    centerY + localX * sinR + localY * cosR,
  );
}

/// Drops the part of a polygon that has wrapped around the far side.
///
/// Without this, back-facing geometry folds through the silhouette and the pet
/// grows a second, inside-out face.
List<Vec3> clipToVisibleHemisphere(
  List<Vec3> points, {
  double minimumDepth = 0.015,
}) {
  final clipped = <Vec3>[];
  for (var index = 0; index < points.length; index++) {
    final previous = points[(index + points.length - 1) % points.length];
    final current = points[index];
    final previousVisible = previous.z > minimumDepth;
    final currentVisible = current.z > minimumDepth;

    if (previousVisible != currentVisible) {
      final ratio = (minimumDepth - previous.z) / (current.z - previous.z);
      clipped.add(
        Vec3(
          previous.x + (current.x - previous.x) * ratio,
          previous.y + (current.y - previous.y) * ratio,
          minimumDepth,
        ),
      );
    }
    if (currentVisible) clipped.add(current);
  }
  return clipped;
}

/// Andrew's monotone chain, matching the editor's hull so silhouettes agree.
List<Vec2> convexHull(List<Vec2> points) {
  if (points.length <= 2) return List<Vec2>.of(points);

  final sorted = List<Vec2>.of(points)
    ..sort((left, right) {
      final byX = left.x.compareTo(right.x);
      return byX != 0 ? byX : left.y.compareTo(right.y);
    });

  double turn(Vec2 origin, Vec2 left, Vec2 right) =>
      (left.x - origin.x) * (right.y - origin.y) -
      (left.y - origin.y) * (right.x - origin.x);

  final lower = <Vec2>[];
  for (final point in sorted) {
    while (lower.length >= 2 &&
        turn(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) {
      lower.removeLast();
    }
    lower.add(point);
  }

  final upper = <Vec2>[];
  for (final point in sorted.reversed) {
    while (upper.length >= 2 &&
        turn(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) {
      upper.removeLast();
    }
    upper.add(point);
  }

  if (lower.isNotEmpty) lower.removeLast();
  if (upper.isNotEmpty) upper.removeLast();
  return <Vec2>[...lower, ...upper];
}

/// How dark a surface cell is drawn, from its angle to the light.
///
/// Lit and shadowed sides use different curves on purpose: the editor leans on
/// shadow far more than on highlight, which is what gives these avatars their
/// soft, moulded look instead of a plastic sheen.
double surfaceShadeOpacity(double shade, double lightDistance) {
  final lightStrength = 1 - clampDouble(lightDistance, 0, 100) / 100;
  final normalized = clampDouble(shade, -1, 1).abs();
  final contrast = shade >= 0
      ? normalized * 0.38
      : math.pow(normalized, 0.65).toDouble() * 0.96;
  return contrast * lightStrength;
}
