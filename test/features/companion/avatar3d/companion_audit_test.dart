import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_face_expression.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_geometry.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/species_face.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';

/// Every companion, every feeling, every head turn: nothing may go missing,
/// leave the head, or jump between frames.
void main() {
  final catalog = Map<String, dynamic>.from(
    jsonDecode(
          File('assets/avatars/scenes/avatar_scenes.json').readAsStringSync(),
        )
        as Map,
  );

  AvatarScene sceneFor(String preset) {
    final raw = AvatarScene.fromJson(
      preset,
      Map<String, dynamic>.from(catalog[preset] as Map),
    )!;
    return raw.copyWith(faceStyle: tuneFaceForSpecies(preset, raw.faceStyle));
  }

  /// The pose [Avatar3DView] rests in, turned by [look] and [lift].
  AvatarScene pose(
    AvatarScene scene,
    PetEmotion emotion, {
    double intensity = 1.0,
    double look = 0.0,
    double lift = 0.0,
    double blink = 0.0,
  }) {
    final v = scene.viewState;
    return scene.copyWith(
      viewState: v.copyWith(
        yaw: v.yaw * 0.2 + look * 0.55,
        pitch: v.pitch * 0.2 + lift * 0.55 * 0.7,
        roll: v.roll * 0.2,
      ),
      faceStyle: expressFace(
        scene.faceStyle,
        PetEmotionState(emotion: emotion, intensity: intensity),
      ).withEyeOpenness(1 - blink),
    );
  }

  ui.Rect partBounds(AvatarGeometry g) {
    final host = g.parts.firstWhere((p) => p.part.id == g.facePartId);
    return host.outline.getBounds();
  }

  bool finite(ui.Rect r) =>
      r.left.isFinite &&
      r.top.isFinite &&
      r.right.isFinite &&
      r.bottom.isFinite;

  test('every app species resolves to a scene', () {
    final missing = <String>[
      for (final s in AvatarSpecies.values)
        if (!hasAvatarScene(s.name) ||
            !catalog.containsKey(avatarPresetFor(s.name)))
          s.name,
    ];
    expect(missing, isEmpty, reason: 'species with no 3D scene: $missing');
  });

  group('every scene', () {
    for (final preset in catalog.keys) {
      test('$preset keeps its face, features and frame', () {
        final scene = sceneFor(preset);
        final rest = buildAvatarGeometry(
          pose(scene, PetEmotion.content, intensity: 0.5),
          densityScale: 0.75,
        );
        final restBounds = rest.bounds;
        expect(finite(restBounds), isTrue, reason: 'rest bounds');
        expect(rest.face.eyes.length, 2, reason: 'rest shows both eyes');

        final problems = <String>[];
        for (final emotion in PetEmotion.values) {
          for (final intensity in const [0.3, 1.0]) {
            for (final look in const [-1.0, 0.0, 1.0]) {
              for (final lift in const [-1.0, 0.0, 1.0]) {
                final g = buildAvatarGeometry(
                  pose(
                    scene,
                    emotion,
                    intensity: intensity,
                    look: look,
                    lift: lift,
                  ),
                  densityScale: 0.75,
                );
                final tag = '${emotion.name}@$intensity look=$look lift=$lift';
                if (!finite(g.bounds)) problems.add('$tag: bounds not finite');
                // The silhouette must not balloon or collapse.
                final ratioW = g.bounds.width / restBounds.width;
                final ratioH = g.bounds.height / restBounds.height;
                if (ratioW < 0.7 ||
                    ratioW > 1.4 ||
                    ratioH < 0.7 ||
                    ratioH > 1.4) {
                  problems.add(
                    '$tag: frame ${ratioW.toStringAsFixed(2)}x'
                    '${ratioH.toStringAsFixed(2)} of rest',
                  );
                }
                // At moderate turns the face must still show both eyes.
                if (look.abs() < 1 &&
                    lift.abs() < 1 &&
                    g.face.eyes.length < 2) {
                  problems.add('$tag: ${g.face.eyes.length} eyes visible');
                }
                // Every feature must stay on the head.
                final head = partBounds(g).inflate(1.0);
                for (final f in [
                  ...g.face.eyes,
                  if (g.face.nose != null) g.face.nose!,
                  if (g.face.mouth != null) g.face.mouth!,
                ]) {
                  final b = f.path.getBounds();
                  if (!finite(b)) {
                    problems.add('$tag: feature not finite');
                  } else if (!head.contains(b.topLeft) ||
                      !head.contains(b.bottomRight)) {
                    problems.add('$tag: feature leaves the head');
                    break;
                  }
                }
              }
            }
          }
        }
        expect(problems, isEmpty, reason: problems.take(8).join('\n'));
      });

      test('$preset has eyes big enough to read an expression from', () {
        double eyeRatio(AvatarScene s) {
          final g = buildAvatarGeometry(
            pose(s, PetEmotion.content, intensity: 0.5),
            densityScale: 0.75,
          );
          final host = partBounds(g);
          final tallest = g.face.eyes
              .map((e) => e.path.getBounds().height)
              .reduce((a, b) => a > b ? a : b);
          return tallest / host.height;
        }

        final raw = AvatarScene.fromJson(
          preset,
          Map<String, dynamic>.from(catalog[preset] as Map),
        )!;
        final authored = eyeRatio(raw);
        final tuned = eyeRatio(sceneFor(preset));
        expect(
          tuned,
          greaterThanOrEqualTo(authored * 0.7),
          reason:
              'eyes are ${(tuned * 100).toStringAsFixed(1)}% of the head, '
              'the illustrator drew ${(authored * 100).toStringAsFixed(1)}%',
        );
        expect(tuned, greaterThan(0.10), reason: 'absolute floor');
      });

      test('$preset turns its head smoothly', () {
        final scene = sceneFor(preset);
        ui.Offset? previous;
        double worst = 0;
        for (var i = 0; i <= 60; i++) {
          final look = -1.0 + 2.0 * i / 60;
          final g = buildAvatarGeometry(
            pose(scene, PetEmotion.content, intensity: 0.5, look: look),
            densityScale: 0.75,
          );
          if (g.face.eyes.length < 2) {
            previous = null;
            continue;
          }
          final c = ui.Offset(
            (g.face.eyes[0].path.getBounds().center.dx +
                    g.face.eyes[1].path.getBounds().center.dx) /
                2,
            (g.face.eyes[0].path.getBounds().center.dy +
                    g.face.eyes[1].path.getBounds().center.dy) /
                2,
          );
          if (previous != null) {
            worst = worst < (c - previous).distance
                ? (c - previous).distance
                : worst;
          }
          previous = c;
        }
        // A full sweep in 60 steps, in a 440-unit scene: a step bigger than
        // this is a pop, not motion.
        expect(worst, lessThan(14.0), reason: 'largest eye jump $worst');
      });
    }
  });
}
