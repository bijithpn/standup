import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_style.dart';

AvatarScene _scene(String preset) {
  final catalog = jsonDecode(
    File('assets/avatars/scenes/avatar_scenes.json').readAsStringSync(),
  ) as Map;
  final scene = AvatarScene.fromJson(
    preset,
    Map<String, dynamic>.from(catalog[preset] as Map),
  );
  if (scene == null) throw StateError('no scene for $preset');
  return scene;
}

void main() {
  group('storage', () {
    test('an untouched style stores nothing at all', () {
      final parts = withAvatarStyle(
        <String, dynamic>{'ears': 2},
        AvatarSceneStyle.authored,
      );

      // Nothing overridden means nothing written, so a companion saved before
      // styling existed and one saved after it are the same bytes.
      expect(parts.containsKey(kAvatarStyleKey), isFalse);
      expect(parts['ears'], 2);
    });

    test('clearing a style removes it again rather than storing defaults', () {
      var parts = withAvatarStyle(
        const <String, dynamic>{},
        const AvatarSceneStyle(faceScale: 1.3),
      );
      expect(parts.containsKey(kAvatarStyleKey), isTrue);

      parts = withAvatarStyle(parts, AvatarSceneStyle.authored);
      expect(parts.containsKey(kAvatarStyleKey), isFalse);
    });

    test('survives a round trip through JSON', () {
      const style = AvatarSceneStyle(
        showOutline: false,
        outlineWidth: 1.8,
        showShadow: true,
        lightAzimuth: -120,
        lightElevation: 12,
        faceScale: 1.2,
        eyeSpacing: 0.85,
        eyeSparkle: true,
        nose: false,
      );

      final parts = withAvatarStyle(const <String, dynamic>{}, style);
      // Through a real encode, because this is how it reaches the overlay.
      final decoded = jsonDecode(jsonEncode(parts)) as Map;

      expect(avatarStyleFrom(Map<String, dynamic>.from(decoded)), style);
    });

    test('unset fields stay unset rather than becoming zero', () {
      final style = avatarStyleFrom(<String, dynamic>{
        kAvatarStyleKey: <String, dynamic>{'faceScale': 1.1},
      });

      expect(style.faceScale, 1.1);
      expect(style.showOutline, isNull);
      expect(style.lightAzimuth, isNull);
      expect(style.isAuthored, isFalse);
    });

    test('rubbish in the part map is ignored', () {
      expect(
        avatarStyleFrom(<String, dynamic>{kAvatarStyleKey: 'not a map'}),
        AvatarSceneStyle.authored,
      );
      expect(
        avatarStyleFrom(<String, dynamic>{
          kAvatarStyleKey: <String, dynamic>{'faceScale': 'big'},
        }).faceScale,
        isNull,
      );
    });
  });

  group('applying', () {
    test('an untouched style returns the very same scene', () {
      final scene = _scene('cat');
      expect(identical(AvatarSceneStyle.authored.applyTo(scene), scene), isTrue);
    });

    test('light direction and height reach the scene', () {
      final styled = const AvatarSceneStyle(
        lightAzimuth: 140,
        lightElevation: 15,
      ).applyTo(_scene('cat'));

      expect(styled.lightAzimuth, 140);
      expect(styled.lightElevation, 15);
    });

    test('an out-of-range elevation is clamped, not passed through', () {
      final styled =
          const AvatarSceneStyle(lightElevation: 400).applyTo(_scene('cat'));

      expect(styled.lightElevation, AvatarSceneStyle.maxElevation);
    });

    test('outline weight scales the authored stroke', () {
      final scene = _scene('cat');
      final styled =
          const AvatarSceneStyle(outlineWidth: 2.0).applyTo(scene);

      expect(styled.outlineStyle.width, scene.outlineStyle.width * 2.0);
      // The colour is the illustrator's choice, not the user's.
      expect(styled.outlineStyle.color, scene.outlineStyle.color);
    });

    test('a scene with no outline can still be given one', () {
      final bare = _scene('cat').copyWith(
        outlineStyle: const AvatarOutlineStyle(
          color: Color(0xFF101010),
          opacity: 100,
          width: 0,
        ),
      );

      final styled =
          const AvatarSceneStyle(outlineWidth: 1.0).applyTo(bare);

      // Scaling zero gives zero, so asking for an outline on a scene drawn
      // without one has to start from a real weight or the control does
      // nothing at all.
      expect(styled.outlineStyle.width, greaterThan(0));
    });

    test('face size grows the eyes, the mouth and the gap together', () {
      final scene = _scene('cat');
      final styled = const AvatarSceneStyle(faceScale: 1.3).applyTo(scene);

      expect(styled.faceStyle.height, closeTo(scene.faceStyle.height * 1.3, 1e-9));
      expect(styled.faceStyle.width, closeTo(scene.faceStyle.width * 1.3, 1e-9));
      expect(styled.faceStyle.gap, closeTo(scene.faceStyle.gap * 1.3, 1e-9));
      expect(
        styled.faceStyle.mouthWidth,
        closeTo(scene.faceStyle.mouthWidth * 1.3, 1e-9),
      );
      // The mouth travels with the eyes; left where it was, a bigger face
      // would end up with its mouth on its chin.
      expect(styled.faceStyle.mouthY, closeTo(scene.faceStyle.mouthY * 1.3, 1e-9));
    });

    test('eye spacing moves the eyes without resizing them', () {
      final scene = _scene('cat');
      final styled = const AvatarSceneStyle(eyeSpacing: 1.25).applyTo(scene);

      expect(styled.faceStyle.gap, closeTo(scene.faceStyle.gap * 1.25, 1e-9));
      expect(styled.faceStyle.width, scene.faceStyle.width);
      expect(styled.faceStyle.height, scene.faceStyle.height);
    });

    test('styling never changes the eye shape the species was drawn with', () {
      final scene = _scene('cat');
      final styled = const AvatarSceneStyle(
        faceScale: 1.45,
        eyeSpacing: 0.7,
        nose: true,
        eyeSparkle: true,
      ).applyTo(scene);

      expect(styled.faceStyle.eyeShape, scene.faceStyle.eyeShape);
      expect(styled.faceStyle.eyeRoundness, scene.faceStyle.eyeRoundness);
      expect(styled.faceStyle.noseY, scene.faceStyle.noseY);
    });

    test('outline and shadow can be switched off', () {
      final styled = const AvatarSceneStyle(
        showOutline: false,
        showShadow: false,
      ).applyTo(_scene('cat'));

      expect(styled.showOutline, isFalse);
      expect(styled.showAvatarShadow, isFalse);
    });

    test('leaves the parts and the camera exactly as they were', () {
      final scene = _scene('bear');
      final styled = const AvatarSceneStyle(
        faceScale: 1.2,
        lightAzimuth: 90,
        showOutline: false,
      ).applyTo(scene);

      // Styling is a surface treatment: the model underneath must not move,
      // or the companion stops being the one the user picked.
      expect(styled.parts.length, scene.parts.length);
      expect(identical(styled.parts, scene.parts), isTrue);
      expect(styled.viewState.yaw, scene.viewState.yaw);
      expect(styled.viewState.scale, scene.viewState.scale);
      expect(styled.cameraBackground, scene.cameraBackground);
    });
  });

  group('azimuth', () {
    test('wraps into -180..180 so a dial can spin without drift', () {
      expect(normaliseAzimuth(0), 0);
      expect(normaliseAzimuth(190), -170);
      expect(normaliseAzimuth(-190), 170);
      expect(normaliseAzimuth(540), 180);
    });
  });
}
