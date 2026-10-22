import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_geometry.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_shape.dart';

Map<String, dynamic> _readCatalog() {
  final file = File('assets/avatars/scenes/avatar_scenes.json');
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}

AvatarScene _scene(String preset) {
  final catalog = _readCatalog();
  final raw = Map<String, dynamic>.from(catalog[preset] as Map);
  final scene = AvatarScene.fromJson(preset, raw);
  expect(scene, isNotNull, reason: '$preset should parse');
  return scene!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('scene data', () {
    test('every authored species parses into a scene', () {
      final catalog = _readCatalog();
      expect(catalog.length, greaterThanOrEqualTo(30));

      for (final entry in catalog.entries) {
        final scene = AvatarScene.fromJson(
          entry.key,
          Map<String, dynamic>.from(entry.value as Map),
        );
        expect(scene, isNotNull, reason: '${entry.key} failed to parse');
        expect(scene!.parts, isNotEmpty);
        for (final part in scene.parts) {
          expect(
            kShapeSpecs.containsKey(part.shape),
            isTrue,
            reason: '${entry.key}/${part.id} uses an unknown primitive',
          );
        }
      }
    });

    test('the cat keeps the colours and camera the editor authored', () {
      final cat = _scene('cat');

      expect(cat.parts.length, 3);
      // The camera background is data now, not something baked into artwork,
      // so the app can show it, recolour it, or leave it off.
      expect(cat.cameraBackground, isNotNull);
      expect(cat.outlineStyle.width, greaterThan(0));
      expect(cat.shadowStyle.opacity, greaterThan(0));
      expect(cat.viewState.yaw, isNot(0));
    });
  });

  group('geometry', () {
    test('builds shaded, depth-sorted cells for every part', () {
      final geometry = buildAvatarGeometry(_scene('cat'));

      expect(geometry.parts.length, 3);
      for (final part in geometry.parts) {
        expect(
          part.cells,
          isNotEmpty,
          reason: '${part.part.id} has no surface',
        );
        // Only the hemisphere facing the camera is generated.
        for (final cell in part.cells) {
          expect(cell.shade, inInclusiveRange(-1.0, 1.0));
        }
        // Nearer cells paint last.
        for (var i = 1; i < part.cells.length; i++) {
          expect(
            part.cells[i].depth,
            greaterThanOrEqualTo(part.cells[i - 1].depth),
          );
        }
      }
    });

    test('parts are ordered back to front', () {
      final geometry = buildAvatarGeometry(_scene('hedgehog'));
      for (var i = 1; i < geometry.parts.length; i++) {
        expect(
          geometry.parts[i].depth,
          greaterThanOrEqualTo(geometry.parts[i - 1].depth),
        );
      }
    });

    test('turning the head swings the face around it', () {
      final scene = _scene('cat');
      final straightOn = buildAvatarGeometry(
        scene.copyWith(viewState: scene.viewState.copyWith(yaw: 0, pitch: 0)),
      );
      final turned = buildAvatarGeometry(
        scene.copyWith(viewState: scene.viewState.copyWith(yaw: 0.6, pitch: 0)),
      );

      // A symmetric head keeps the same bounding box under yaw, so the
      // silhouette proves nothing here — where the face sits on it does.
      final before = straightOn.face.eyes.first.path.getBounds().center.dx;
      final after = turned.face.eyes.first.path.getBounds().center.dx;

      expect(
        (after - before).abs(),
        greaterThan(8),
        reason: 'the face must travel across the head as it turns',
      );
    });

    test('an ear on the far side falls behind the head', () {
      final scene = _scene('cat');
      PartGeometry partFor(AvatarGeometry geometry, String id) =>
          geometry.parts.firstWhere((part) => part.part.id.contains(id));

      final leftward = buildAvatarGeometry(
        scene.copyWith(
          viewState: scene.viewState.copyWith(yaw: -0.9, pitch: 0),
        ),
      );
      final rightward = buildAvatarGeometry(
        scene.copyWith(viewState: scene.viewState.copyWith(yaw: 0.9, pitch: 0)),
      );

      // Track one ear against the other. Turning the head the other way has
      // to flip which of the two is nearer, or the painter would stack them
      // in the same order from both sides.
      double leftRelativeToRight(AvatarGeometry geometry) =>
          partFor(geometry, 'ear-left').depth -
          partFor(geometry, 'ear-right').depth;

      expect(
        leftRelativeToRight(leftward).sign,
        isNot(leftRelativeToRight(rightward).sign),
        reason: 'the near ear must swap sides with the yaw',
      );
    });

    test('rotates in every direction, not just left and right', () {
      final scene = _scene('cat');
      final base = buildAvatarGeometry(
        scene.copyWith(viewState: scene.viewState.copyWith(yaw: 0, pitch: 0)),
      );
      final pitched = buildAvatarGeometry(
        scene.copyWith(viewState: scene.viewState.copyWith(yaw: 0, pitch: 0.5)),
      );

      expect(
        pitched.bounds.center.dy,
        isNot(closeTo(base.bounds.center.dy, 0.5)),
        reason: 'pitch must tilt the scene, not just yaw',
      );
    });

    test('the face is hidden once the head turns away from the camera', () {
      final scene = _scene('cat');
      final facing = buildAvatarGeometry(
        scene.copyWith(viewState: scene.viewState.copyWith(yaw: 0, pitch: 0)),
      );
      final awayFromCamera = buildAvatarGeometry(
        scene.copyWith(
          viewState: scene.viewState.copyWith(yaw: math.pi, pitch: 0),
        ),
      );

      expect(facing.face.eyes, isNotEmpty);
      expect(
        awayFromCamera.face.eyes,
        isEmpty,
        reason: 'eyes on the far side must be clipped away',
      );
    });

    test('every species builds without throwing', () {
      final catalog = _readCatalog();
      for (final key in catalog.keys) {
        final geometry = buildAvatarGeometry(_scene(key));
        expect(geometry.parts, isNotEmpty, reason: '$key produced nothing');
        expect(geometry.bounds.width, greaterThan(0), reason: '$key is empty');
      }
    });

    test('a lower density trims the mesh without losing the silhouette', () {
      final scene = _scene('cat');
      final full = buildAvatarGeometry(scene);
      final light = buildAvatarGeometry(scene, densityScale: 0.5);

      final fullCells = full.parts.fold<int>(
        0,
        (sum, part) => sum + part.cells.length,
      );
      final lightCells = light.parts.fold<int>(
        0,
        (sum, part) => sum + part.cells.length,
      );

      expect(lightCells, lessThan(fullCells));
      expect(light.bounds.width, closeTo(full.bounds.width, 4));
    });
  });

  group('cost', () {
    test('a full rebuild is affordable at frame rate', () {
      final scene = _scene('cat');
      buildAvatarGeometry(scene); // warm

      const iterations = 21;
      final timings = <double>[];
      for (var i = 0; i < iterations; i++) {
        final stopwatch = Stopwatch()..start();
        buildAvatarGeometry(
          scene.copyWith(viewState: scene.viewState.copyWith(yaw: i * 0.01)),
        );
        stopwatch.stop();
        timings.add(stopwatch.elapsedMicroseconds / 1000);
      }
      timings.sort();
      final median = timings[timings.length ~/ 2];

      // The median, not the mean: one scheduling hiccup while the rest of the
      // suite runs should not read as a performance regression.
      //
      // The budget is deliberately loose. Geometry is cached until the pose
      // actually moves and the density is scaled down for small surfaces, so
      // the question this guards is "is a rebuild still cheap enough to do on
      // demand" — not "is this machine fast today". A real regression here,
      // like the tessellation density escaping, costs hundreds of
      // milliseconds rather than tens.
      expect(
        median,
        lessThan(30.0),
        reason: 'median rebuild took ${median.toStringAsFixed(2)} ms',
      );
    });
  });
}
