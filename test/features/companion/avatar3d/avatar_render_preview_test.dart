import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_geometry.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_face_expression.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_palette_mapper.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_painter.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_style.dart';

/// Renders companions to PNG so the result can actually be looked at.
///
/// Not an assertion of correctness — it is the only way to see what the
/// renderer produces without building the desktop app, and a silhouette that
/// has gone wrong is obvious in a picture and invisible in a number.
///
/// Set `AVATAR_PREVIEW_DIR` to choose where the images land.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final outputDir = Platform.environment['AVATAR_PREVIEW_DIR'];

  Map<String, dynamic> readCatalog() => Map<String, dynamic>.from(
    jsonDecode(
          File('assets/avatars/scenes/avatar_scenes.json').readAsStringSync(),
        )
        as Map,
  );

  Future<void> renderSheet({
    required String name,
    required List<String> presets,
    required List<double> yaws,
    required bool withBackground,
  }) async {
    if (outputDir == null) return;

    const cell = 220.0;
    final catalog = readCatalog();
    final width = cell * yaws.length;
    final height = cell * presets.length;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF2A2A31),
    );

    for (var row = 0; row < presets.length; row++) {
      final scene = AvatarScene.fromJson(
        presets[row],
        Map<String, dynamic>.from(catalog[presets[row]] as Map),
      );
      if (scene == null) continue;

      for (var column = 0; column < yaws.length; column++) {
        final posed = scene.copyWith(
          viewState: scene.viewState.copyWith(
            yaw: scene.viewState.yaw + yaws[column],
            pitch: scene.viewState.pitch,
          ),
        );
        final geometry = buildAvatarGeometry(posed);

        canvas.save();
        canvas.translate(column * cell, row * cell);
        canvas.clipRect(const Rect.fromLTWH(0, 0, cell, cell));
        AvatarScenePainter(
          geometry: geometry,
          scene: posed,
          background: withBackground ? posed.cameraBackground : null,
        ).paint(canvas, const Size(cell, cell));
        canvas.restore();
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), height.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;

    Directory(outputDir).createSync(recursive: true);
    File('$outputDir/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
  }

  test('renders every emotion, to check each one reads', () async {
    if (outputDir == null) return;

    const emotions = PetEmotion.values;
    const species = <String>['cat', 'bear', 'rabbit'];
    const cell = 190.0;

    final catalog = readCatalog();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cell * emotions.length, cell * species.length),
      Paint()..color = const Color(0xFF2A2A31),
    );

    for (var row = 0; row < species.length; row++) {
      final base = AvatarScene.fromJson(
        species[row],
        Map<String, dynamic>.from(catalog[species[row]] as Map),
      );
      if (base == null) continue;

      for (var column = 0; column < emotions.length; column++) {
        final scene = base.copyWith(
          faceStyle: expressFace(
            base.faceStyle,
            PetEmotionState(emotion: emotions[column], intensity: 1),
          ),
        );
        final geometry = buildAvatarGeometry(scene);

        canvas.save();
        canvas.translate(column * cell, row * cell);
        canvas.clipRect(const Rect.fromLTWH(0, 0, cell, cell));
        AvatarScenePainter(
          geometry: geometry,
          scene: scene,
        ).paint(canvas, const Size(cell, cell));
        canvas.restore();
      }
    }

    final image = await recorder.endRecording().toImage(
      (cell * emotions.length).round(),
      (cell * species.length).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;

    Directory(outputDir).createSync(recursive: true);
    File(
      '$outputDir/emotions.png',
    ).writeAsBytesSync(bytes.buffer.asUint8List());
  });

  test('renders the same species under several palettes', () async {
    if (outputDir == null) return;

    const palettes = <AvatarPalette>[
      AvatarPalette.defaultPalette,
      AvatarPalette.coolBlue,
      AvatarPalette.cyberpunk,
      AvatarPalette.forest,
      AvatarPalette.pastelPink,
    ];
    const species = <String>['cat', 'dog', 'bear', 'penguin'];
    const cell = 200.0;

    final catalog = readCatalog();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cell * palettes.length, cell * species.length),
      Paint()..color = const Color(0xFF2A2A31),
    );

    for (var row = 0; row < species.length; row++) {
      final base = AvatarScene.fromJson(
        species[row],
        Map<String, dynamic>.from(catalog[species[row]] as Map),
      );
      if (base == null) continue;

      for (var column = 0; column < palettes.length; column++) {
        final scene = applyPalette(base, column == 0 ? null : palettes[column]);
        final geometry = buildAvatarGeometry(scene);

        canvas.save();
        canvas.translate(column * cell, row * cell);
        canvas.clipRect(const Rect.fromLTWH(0, 0, cell, cell));
        AvatarScenePainter(
          geometry: geometry,
          scene: scene,
        ).paint(canvas, const Size(cell, cell));
        canvas.restore();
      }
    }

    final image = await recorder.endRecording().toImage(
      (cell * palettes.length).round(),
      (cell * species.length).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;

    Directory(outputDir).createSync(recursive: true);
    File(
      '$outputDir/palettes.png',
    ).writeAsBytesSync(bytes.buffer.asUint8List());
  });

  test('renders each style control at both ends of its range', () async {
    if (outputDir == null) return;

    // Each row is one control swept from one extreme to the other, so a
    // control that does nothing — or does something grotesque — is obvious.
    const sweeps = <String, List<AvatarSceneStyle>>{
      'face size': <AvatarSceneStyle>[
        AvatarSceneStyle(faceScale: 0.7),
        AvatarSceneStyle(faceScale: 0.85),
        AvatarSceneStyle.authored,
        AvatarSceneStyle(faceScale: 1.2),
        AvatarSceneStyle(faceScale: 1.45),
      ],
      'eye spacing': <AvatarSceneStyle>[
        AvatarSceneStyle(eyeSpacing: 0.7),
        AvatarSceneStyle(eyeSpacing: 0.85),
        AvatarSceneStyle.authored,
        AvatarSceneStyle(eyeSpacing: 1.2),
        AvatarSceneStyle(eyeSpacing: 1.4),
      ],
      'outline': <AvatarSceneStyle>[
        AvatarSceneStyle(showOutline: false),
        AvatarSceneStyle(outlineWidth: 0.5),
        AvatarSceneStyle.authored,
        AvatarSceneStyle(outlineWidth: 1.7),
        AvatarSceneStyle(outlineWidth: 2.5),
      ],
      'light': <AvatarSceneStyle>[
        AvatarSceneStyle(lightAzimuth: -160),
        AvatarSceneStyle(lightAzimuth: -90),
        AvatarSceneStyle.authored,
        AvatarSceneStyle(lightAzimuth: 90),
        AvatarSceneStyle(lightAzimuth: 160),
      ],
      'light height': <AvatarSceneStyle>[
        AvatarSceneStyle(lightElevation: -20),
        AvatarSceneStyle(lightElevation: 5),
        AvatarSceneStyle.authored,
        AvatarSceneStyle(lightElevation: 60),
        AvatarSceneStyle(lightElevation: 85),
      ],
      // Most species are authored with a nose and without an eye highlight,
      // so the informative sweep is one off and the other on.
      'extras': <AvatarSceneStyle>[
        AvatarSceneStyle(nose: false),
        AvatarSceneStyle(showShadow: false),
        AvatarSceneStyle.authored,
        AvatarSceneStyle(eyeSparkle: true),
        AvatarSceneStyle(eyeSparkle: true, faceScale: 1.3, eyeSpacing: 1.1),
      ],
    };

    const cell = 190.0;
    final rows = sweeps.values.toList();
    final catalog = readCatalog();
    final base = AvatarScene.fromJson(
      'cat',
      Map<String, dynamic>.from(catalog['cat'] as Map),
    );
    if (base == null) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cell * 5, cell * rows.length),
      Paint()..color = const Color(0xFF2A2A31),
    );

    for (var row = 0; row < rows.length; row++) {
      for (var column = 0; column < rows[row].length; column++) {
        final scene = rows[row][column].applyTo(base);
        final geometry = buildAvatarGeometry(scene);

        canvas.save();
        canvas.translate(column * cell, row * cell);
        canvas.clipRect(const Rect.fromLTWH(0, 0, cell, cell));
        AvatarScenePainter(
          geometry: geometry,
          scene: scene,
        ).paint(canvas, const Size(cell, cell));
        canvas.restore();
      }
    }

    final image = await recorder.endRecording().toImage(
      (cell * 5).round(),
      (cell * rows.length).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;

    Directory(outputDir).createSync(recursive: true);
    File('$outputDir/styles.png').writeAsBytesSync(bytes.buffer.asUint8List());
  });

  test('renders a turnaround of a few species', () async {
    await renderSheet(
      name: 'turnaround',
      presets: <String>['cat', 'dog', 'bear', 'penguin'],
      yaws: <double>[-0.9, -0.45, 0, 0.45, 0.9],
      withBackground: true,
    );
  });

  test('renders every species head-on, on and off its card', () async {
    final presets = readCatalog().keys.toList()..sort();
    await renderSheet(
      name: 'all-species-on-card',
      presets: presets.sublist(0, 16),
      yaws: <double>[0],
      withBackground: true,
    );
    await renderSheet(
      name: 'all-species-transparent',
      presets: presets.sublist(16),
      yaws: <double>[0],
      withBackground: false,
    );
  });
}
