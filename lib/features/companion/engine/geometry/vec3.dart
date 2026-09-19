import 'dart:math' as math;

/// A lightweight 3D vector primitive with full vector operations.
class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  static const Vec3 zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);
  Vec3 operator -() => Vec3(-x, -y, -z);
  Vec3 operator *(double scalar) => Vec3(x * scalar, y * scalar, z * scalar);
  Vec3 operator /(double scalar) => Vec3(x / scalar, y / scalar, z / scalar);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  Vec3 cross(Vec3 other) => Vec3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  double get lengthSquared => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSquared);

  Vec3 normalized() {
    final len = length;
    if (len == 0.0) return Vec3.zero;
    return this / len;
  }

  Vec3 rotateX(double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return Vec3(
      x,
      y * cosA - z * sinA,
      y * sinA + z * cosA,
    );
  }

  Vec3 rotateY(double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return Vec3(
      x * cosA + z * sinA,
      y,
      -x * sinA + z * cosA,
    );
  }

  Vec3 rotateZ(double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return Vec3(
      x * cosA - y * sinA,
      x * sinA + y * cosA,
      z,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vec3 &&
          (x - other.x).abs() < 1e-6 &&
          (y - other.y).abs() < 1e-6 &&
          (z - other.z).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(x.toStringAsFixed(5), y.toStringAsFixed(5), z.toStringAsFixed(5));

  @override
  String toString() => 'Vec3(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}
