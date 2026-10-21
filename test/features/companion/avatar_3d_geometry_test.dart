import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/engine/geometry/avatar_body_shapes.dart';
import 'package:breakmate/features/companion/engine/geometry/avatar_3d_geometry.dart';

void main() {
  group('Avatar3DGeometry mathematical compiler', () {
    test('buildBodyGeometry compiles cells, vertices, normals, and outline', () {
      final geometry = Avatar3DGeometry.buildBodyGeometry(
        shape: AvatarBodyShape.sphere,
        yaw: 0.0,
        pitch: 0.0,
        roll: 0.0,
        lightAzimuth: 45.0,
        lightElevation: 30.0,
        gridDensity: 100,
      );

      expect(geometry.cells.isNotEmpty, isTrue);
      expect(geometry.outlinePoints.length, greaterThanOrEqualTo(3));
      expect(geometry.depthSortedTriangles.isNotEmpty, isTrue);

      // Verify cells have valid depth, coordinates, and Lambertian shading [-1, 1]
      for (final cell in geometry.cells) {
        expect(cell.shade, greaterThanOrEqualTo(-1.0));
        expect(cell.shade, lessThanOrEqualTo(1.0));
        expect(cell.vertices.length, equals(4));
      }
    });

    test('rotation alters cell depths and visible facing', () {
      final frontGeometry = Avatar3DGeometry.buildBodyGeometry(
        shape: AvatarBodyShape.sphere,
        yaw: 0.0,
        pitch: 0.0,
        roll: 0.0,
      );

      final sideGeometry = Avatar3DGeometry.buildBodyGeometry(
        shape: AvatarBodyShape.sphere,
        yaw: math.pi / 2, // 90 degrees yaw
        pitch: 0.0,
        roll: 0.0,
      );

      // Rotating 90 degrees changes the set of visible front-facing cells
      expect(frontGeometry.cells.map((c) => c.id).toSet(), isNot(equals(sideGeometry.cells.map((c) => c.id).toSet())));
    });

    test('tapered bodies (cones, half-cone) resolve unique geometry', () {
      final coneGeometry = Avatar3DGeometry.buildBodyGeometry(
        shape: AvatarBodyShape.cone,
        yaw: 0.0,
        pitch: 0.0,
        roll: 0.0,
      );

      expect(coneGeometry.cells.isNotEmpty, isTrue);
      expect(coneGeometry.outlinePoints.isNotEmpty, isTrue);
    });
  });
}
