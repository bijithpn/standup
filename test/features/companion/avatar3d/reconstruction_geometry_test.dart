import 'dart:convert';
import 'dart:io';

import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_face_expression.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_shape.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AvatarSceneCatalog.instance.load();
  });
  test('all 32 heads have independent anatomy and no body geometry', () {
    final signatures = <String>{};
    for (final species in AvatarSpecies.values) {
      final scene = AvatarSceneCatalog.instance.sceneFor(
        avatarPresetFor(species.name),
      )!;
      final head = scene.facePart!;
      expect(head.shape, isNot(AvatarBodyShape.organic), reason: species.name);
      expect(scene.faceStyle.eyeShape, 'reference-rounded');
      expect(
        signatures.add(
          [
            ...scene.parts.expand(
              (p) => [
                p.shape.name,
                p.x,
                p.y,
                p.z,
                p.scaleX,
                p.scaleY,
                p.scaleZ,
                p.rotationZ,
                p.roundness,
                p.topScale,
                p.bottomTaper,
              ],
            ),
          ].join(':'),
        ),
        isTrue,
        reason: species.name,
      );
      expect(
        scene.parts.any(
          (p) => RegExp(
            r'^(torso|chest|paw|forepaw|wing|flipper|tail)',
          ).hasMatch(p.id),
        ),
        isFalse,
        reason: species.name,
      );
    }
  });
  test('alpaca has rounded ears and a projecting muzzle below its eyes', () {
    final alpaca = AvatarSceneCatalog.instance.sceneFor('alpaca')!;
    final head = alpaca.facePart!;
    expect(alpaca.framePadding, .16);
    expect(alpaca.copyWith().framePadding, alpaca.framePadding);
    expect(
      alpaca.copyWithParts(alpaca.parts).framePadding,
      alpaca.framePadding,
    );
    final ears = alpaca.parts.where((p) => p.id.startsWith('ear-')).toList();
    expect(ears, hasLength(2));
    expect(ears.every((p) => p.shape == AvatarBodyShape.ellipse), isTrue);
    expect(head.scaleY / head.scaleX, lessThan(1.2));
    final muzzle = alpaca.parts.firstWhere((p) => p.id == 'muzzle');
    expect(muzzle.z, greaterThan(50));
    expect(
      muzzle.y - 118 * muzzle.scaleY,
      greaterThan(
        head.y +
            (alpaca.faceStyle.eyeOffsetY + alpaca.faceStyle.height / 2) *
                head.scaleY,
      ),
    );
    expect(alpaca.markings, isEmpty);
  });
  test(
    'native primitive samples match the upstream geometry authoring engine',
    () {
      final manifest =
          jsonDecode(
                File(
                  'assets/avatars/scenes/oneworks_source.json',
                ).readAsStringSync(),
              )
              as Map;
      for (final sample in manifest['geometryChecks'] as List) {
        final scene = AvatarSceneCatalog.instance.sceneFor(
          sample['preset'] as String,
        )!;
        final part = scene.parts.firstWhere((p) => p.id == sample['partId']);
        final actual = surfacePoint(
          kShapeSpecs[part.shape]!,
          (sample['longitude'] as num).toDouble(),
          (sample['latitude'] as num).toDouble(),
          options: part.shapeOptions,
        );
        final expected = sample['point'] as List;
        expect(actual.x, closeTo(expected[0] as num, 1e-6));
        expect(actual.y, closeTo(expected[1] as num, 1e-6));
        expect(actual.z, closeTo(expected[2] as num, 1e-6));
      }
    },
  );
  test(
    'reference eye proportions are preserved rather than replaced with dots',
    () {
      final cat = AvatarSceneCatalog.instance.sceneFor('cat')!;
      final dog = AvatarSceneCatalog.instance.sceneFor('dog')!;
      expect(cat.faceStyle.height, 64);
      expect(cat.faceStyle.width, 28);
      expect(dog.facePart!.shape, AvatarBodyShape.trapezoid);
      expect(
        cat.parts.map((p) => p.id),
        containsAll(['cat-head', 'cat-ear-left', 'cat-ear-right']),
      );
    },
  );
  test('avian expressions never enable a mammalian mouth', () {
    for (final species in [
      'parrot',
      'owl',
      'duck',
      'goose',
      'penguin',
      'chick',
    ]) {
      final scene = AvatarSceneCatalog.instance.sceneFor(species)!;
      for (final emotion in PetEmotion.values) {
        expect(
          expressFace(
            scene.faceStyle,
            PetEmotionState(emotion: emotion, intensity: 1),
          ).mouthEnabled,
          isFalse,
          reason: '$species/${emotion.name}',
        );
      }
    }
  });
  test('reference surface markings move with their ear host', () {
    final scene = AvatarSceneCatalog.instance.sceneFor('chinchilla')!;
    final ear = scene.parts.firstWhere((p) => p.id == 'ear-left');
    final region = scene.markings
        .firstWhere((p) => p.targetPartId == ear.id)
        .surfaceRegions;
    expect(region, isNotEmpty);
    expect(region.first.length, greaterThan(3));
    final moved = poseParts(
      scene.parts,
      const FaceRig(earDroop: 1, earRot: 5),
    ).firstWhere((p) => p.id == ear.id);
    expect(moved.rotationZ, isNot(ear.rotationZ));
    expect(moved.scaleX, ear.scaleX);
    expect(moved.scaleY, ear.scaleY);
  });
  test('sheep has a wool silhouette and a compact contrasting lamb face', () {
    final sheep = AvatarSceneCatalog.instance.sceneFor('sheep')!;
    expect(sheep.matte, isTrue);
    expect(sheep.facePart!.scaleX, lessThan(.6));
    expect(
      sheep.parts.where((p) => p.id.startsWith('wool-')).length,
      greaterThanOrEqualTo(8),
    );
    expect(
      sheep.parts.firstWhere((p) => p.id == 'wool-crown-center').baseColor,
      isNot(sheep.facePart!.baseColor),
    );
    expect(
      sheep.parts.firstWhere((p) => p.id == 'ear-left').scaleX,
      greaterThan(sheep.parts.firstWhere((p) => p.id == 'ear-left').scaleY),
    );
  });
  test(
    'parrot uses a real curved hook and an independently moving lower jaw',
    () {
      final parrot = AvatarSceneCatalog.instance.sceneFor('parrot')!;
      final upper = parrot.parts.firstWhere((p) => p.id == 'beak-upper');
      final lower = parrot.parts.firstWhere((p) => p.id == 'beak-lower');
      expect(upper.shape, AvatarBodyShape.hookedBeak);
      final spec = kShapeSpecs[upper.shape]!;
      final front = surfacePoint(spec, 0, 0);
      final tip = surfacePoint(spec, 0, 1.5707963267948966);
      expect(tip.y, greaterThan(front.y));
      expect(front.z - tip.z, greaterThan(50));
      final open = poseParts(parrot.parts, const FaceRig(beak: 1));
      final jaw = open.firstWhere((p) => p.id == lower.id);
      expect(jaw.y, greaterThan(lower.y));
      expect(jaw.rotationX, greaterThan(lower.rotationX));
      expect(open.firstWhere((p) => p.hasFace), same(parrot.facePart));
    },
  );
  test(
    'matte finish survives scene copies and resting eyes have no forced sparkle',
    () {
      for (final species in AvatarSpecies.values) {
        final scene = AvatarSceneCatalog.instance.sceneFor(
          avatarPresetFor(species.name),
        )!;
        expect(scene.matte, isTrue);
        expect(scene.copyWith().matte, isTrue);
        expect(scene.copyWithParts(scene.parts).matte, isTrue);
        final content = expressFace(
          scene.faceStyle,
          const PetEmotionState(emotion: PetEmotion.content, intensity: 1),
        );
        expect(content.highlightEnabled, isFalse, reason: species.name);
      }
    },
  );
  testWidgets(
    'the view settles without adding its own recurring sleepy timer',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Avatar3DView(
            preset: 'sheep',
            size: 96,
            snapshot: PetBehaviorSnapshot(
              emotion: PetEmotionState(
                emotion: PetEmotion.sleepy,
                intensity: 1,
              ),
            ),
          ),
        ),
      );
      for (var frame = 0; frame < 100; frame++) {
        await t.pump(const Duration(milliseconds: 20));
      }
      expect(t.binding.transientCallbackCount, 0);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('reduced motion settles even for a sleepy face', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Avatar3DView(
            preset: 'cat',
            size: 96,
            snapshot: PetBehaviorSnapshot(
              emotion: PetEmotionState(
                emotion: PetEmotion.sleepy,
                intensity: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.binding.transientCallbackCount, 0);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
