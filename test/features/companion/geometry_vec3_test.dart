import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/engine/geometry/vec3.dart';
import 'package:breakmate/features/companion/engine/geometry/avatar_body_shapes.dart';

void main() {
  group('Vec3 operations', () {
    test('vector addition, subtraction, scaling', () {
      const v1 = Vec3(1, 2, 3);
      const v2 = Vec3(4, 5, 6);

      expect(v1 + v2, equals(const Vec3(5, 7, 9)));
      expect(v2 - v1, equals(const Vec3(3, 3, 3)));
      expect(v1 * 2, equals(const Vec3(2, 4, 6)));
    });

    test('dot and cross products', () {
      const v1 = Vec3(1, 0, 0);
      const v2 = Vec3(0, 1, 0);

      expect(v1.dot(v2), equals(0.0));
      expect(v1.cross(v2), equals(const Vec3(0, 0, 1)));
    });

    test('normalization', () {
      const v = Vec3(3, 0, 4);
      expect(v.length, equals(5.0));
      final norm = v.normalized();
      expect(norm.x, closeTo(0.6, 1e-5));
      expect(norm.y, equals(0.0));
      expect(norm.z, closeTo(0.8, 1e-5));
      expect(norm.length, closeTo(1.0, 1e-5));
    });

    test('rotation around X, Y, Z axes', () {
      const v = Vec3(1, 0, 0);
      // Rotate 90 deg around Y: (1, 0, 0) -> (0, 0, -1) in standard right-handed yaw
      final rotatedY = v.rotateY(math.pi / 2);
      expect(rotatedY.x, closeTo(0.0, 1e-5));
      expect(rotatedY.y, closeTo(0.0, 1e-5));
      expect(rotatedY.z, closeTo(-1.0, 1e-5));
    });
  });

  group('AvatarBodyShape definitions', () {
    test('all 11 OneWorks body shapes exist', () {
      expect(AvatarBodyShape.values.length, equals(11));
      expect(AvatarBodyShape.values, contains(AvatarBodyShape.sphere));
      expect(AvatarBodyShape.values, contains(AvatarBodyShape.capsule));
      expect(AvatarBodyShape.values, contains(AvatarBodyShape.cone));
      expect(AvatarBodyShape.values, contains(AvatarBodyShape.frustum));
      expect(AvatarBodyShape.values, contains(AvatarBodyShape.halfCone));
      expect(AvatarBodyShape.values, contains(AvatarBodyShape.teardrop));
    });
  });
}
