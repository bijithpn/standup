import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_face_expression.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_geometry.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_palette_mapper.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_painter.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_style.dart';
import 'package:breakmate/features/companion/avatar3d/species_face.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/pet_animation_state.dart';

/// Renders the user's real companion avatar into small animated tray frames.
class TrayAvatarRenderer {
  static const int frameCount = 16;
  static const double _px = 72;

  /// Frames per animation state, or null when [def] has no 3D scene.
  static Future<Map<PetAnimationState, List<Uint8List>>?> render(
    AvatarDefinition def,
  ) async {
    if (!hasAvatarScene(def.species.name)) return null;
    final preset = avatarPresetFor(def.species.name);
    final catalog = AvatarSceneCatalog.instance;
    await catalog.load();
    final base = catalog.sceneFor(preset);
    if (base == null) return null;

    final palette = def.palette == AvatarPalette.defaultPalette
        ? null
        : def.palette;
    final scene = avatarStyleFrom(def.parts).applyTo(
      applyPalette(
        base.copyWith(faceStyle: tuneFaceForSpecies(preset, base.faceStyle)),
        palette,
        strength: 0.85,
      ),
    );
    final rest = scene.viewState.copyWith(
      yaw: scene.viewState.yaw * 0.2,
      pitch: scene.viewState.pitch * 0.2,
      roll: scene.viewState.roll * 0.2,
    );
    final fit = buildAvatarGeometry(
      scene.copyWith(viewState: rest),
      densityScale: 0.6,
    ).bounds;

    final out = <PetAnimationState, List<Uint8List>>{};
    for (final state in [
      PetAnimationState.idle,
      PetAnimationState.sleep,
      PetAnimationState.excited,
      PetAnimationState.notification,
    ]) {
      final frames = <Uint8List>[];
      for (var i = 0; i < frameCount; i++) {
        frames.add(await _frame(scene, rest, fit, state, i / frameCount));
      }
      out[state] = frames;
    }
    return out;
  }

  static Future<Uint8List> _frame(
    AvatarScene scene,
    AvatarViewState rest,
    Rect fit,
    PetAnimationState state,
    double t,
  ) async {
    final w = t * math.pi * 2;
    var yaw = 0.0;
    var bounce = 0.0;
    var squash = 1.0;
    var tilt = 0.0;
    var blink = 0.0;
    var emotion = const PetEmotionState(
      emotion: PetEmotion.content,
      intensity: 0.4,
    );

    switch (state) {
      case PetAnimationState.sleep:
        blink = 1;
        bounce = math.sin(w) * 0.8;
        squash = 1 + math.sin(w) * 0.025;
        emotion = const PetEmotionState(
          emotion: PetEmotion.sleepy,
          intensity: 0.9,
        );
      case PetAnimationState.excited:
        bounce = -(math.sin(w).abs()) * 7;
        squash = 1 + (1 - math.sin(w).abs()) * 0.06;
        tilt = math.sin(w) * 0.12;
        yaw = math.sin(w) * 0.35;
        emotion = const PetEmotionState(
          emotion: PetEmotion.excited,
          intensity: 0.9,
        );
      case PetAnimationState.notification:
        tilt = math.sin(w * 3) * 0.16;
        bounce = -math.max(0, math.sin(w * 2)) * 3;
        emotion = const PetEmotionState(
          emotion: PetEmotion.startled,
          intensity: 0.7,
        );
      default:
        bounce = math.sin(w) * 1.2;
        squash = 1 + math.sin(w) * 0.02;
        yaw = math.sin(w) * 0.25;
        blink = (t > 0.62 && t < 0.78) ? 1 : 0;
        emotion = const PetEmotionState(
          emotion: PetEmotion.happy,
          intensity: 0.5,
        );
    }

    final posed = scene.copyWith(
      viewState: rest.copyWith(yaw: rest.yaw + yaw),
      faceStyle: expressFace(scene.faceStyle, emotion, blink: blink),
    );
    final geometry = buildAvatarGeometry(posed, densityScale: 0.6);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, _px, _px));
    canvas.translate(_px / 2, _px / 2 + bounce);
    canvas.rotate(tilt);
    canvas.scale(1 / squash, squash);
    canvas.translate(-_px / 2, -_px / 2);
    AvatarScenePainter(
      geometry: geometry,
      scene: posed,
      fitBounds: fit,
      showShadow: false,
      fitPadding: 0.04,
    ).paint(canvas, const Size(_px, _px));

    final image = await recorder.endRecording().toImage(
      _px.toInt(),
      _px.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
