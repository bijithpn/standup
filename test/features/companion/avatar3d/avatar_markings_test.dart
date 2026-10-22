import 'dart:convert';
import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_geometry.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_palette_mapper.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_painter.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';

void main() {
  final catalog = Map<String, dynamic>.from(
    jsonDecode(
          File('assets/avatars/scenes/avatar_scenes.json').readAsStringSync(),
        )
        as Map,
  );

  test('every marking points at a part that exists', () {
    for (final entry in catalog.entries) {
      final scene = AvatarScene.fromJson(
        entry.key,
        Map<String, dynamic>.from(entry.value as Map),
      )!;
      final ids = scene.parts.map((p) => p.id).toSet();
      for (final mark in scene.markings) {
        expect(ids, contains(mark.targetPartId), reason: entry.key);
        expect(mark.shape, anyOf('ellipse', 'rounded-triangle'));
      }
    }
  });

  test('marked species load their markings, others stay unmarked', () {
    AvatarScene load(String k) =>
        AvatarScene.fromJson(k, Map<String, dynamic>.from(catalog[k] as Map))!;
    for (final k in catalog.keys) {
      expect(load(k).markings, isNotEmpty, reason: k);
    }
  });

  AvatarScene load(String k) =>
      AvatarScene.fromJson(k, Map<String, dynamic>.from(catalog[k] as Map))!;

  test('a palette recolours dark markings but leaves light ones alone', () {
    final scene = load('tiger');
    final tinted = applyPalette(scene, AvatarPalette.coolBlue);
    expect(tinted.markings.length, scene.markings.length);

    final darkBefore = scene.markings.firstWhere((m) => m.color.r < 0.4);
    final darkIndex = scene.markings.indexOf(darkBefore);
    expect(tinted.markings[darkIndex].color, isNot(darkBefore.color));

    final light = scene.markings.indexWhere(
      (m) => m.color.r > 0.9 && m.color.g > 0.85,
    );
    expect(tinted.markings[light].color, scene.markings[light].color);
  });

  test('every species paints with its markings without error', () {
    for (final k in catalog.keys) {
      final scene = load(k);
      final recorder = ui.PictureRecorder();
      AvatarScenePainter(
        geometry: buildAvatarGeometry(scene),
        scene: scene,
      ).paint(Canvas(recorder), const Size(200, 200));
      recorder.endRecording().dispose();
    }
  });
}
