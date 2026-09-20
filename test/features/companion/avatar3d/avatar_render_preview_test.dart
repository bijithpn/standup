import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_geometry.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_painter.dart';

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
        ) as Map,
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
