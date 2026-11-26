// Actual native renderer exports. No image fixtures substitute for runtime output.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:breakmate/features/companion/avatar3d/avatar_face_expression.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_geometry.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_painter.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/avatar3d/species_face.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:flutter_test/flutter_test.dart';

const output = 'build/pet_reconstruction';
const foundation = ['cat', 'dog', 'parrot', 'capybara', 'seal'];
const poses = <String, PetBehaviorSnapshot>{
  'left': PetBehaviorSnapshot(headTurn: Offset(-1, 0), tilt: -.16),
  'right': PetBehaviorSnapshot(headTurn: Offset(1, 0), tilt: .16),
  'up': PetBehaviorSnapshot(headTurn: Offset(0, -1)),
  'down': PetBehaviorSnapshot(headTurn: Offset(0, 1)),
  'corner': PetBehaviorSnapshot(headTurn: Offset(1, 1), tilt: .2),
  'squash': PetBehaviorSnapshot(squash: 1.14, bounce: 12),
  'stretch': PetBehaviorSnapshot(squash: .9, bounce: -14),
  'lean': PetBehaviorSnapshot(bodyLean: Offset(1, .5)),
};

AvatarScene resolve(AvatarScene base, PetBehaviorSnapshot s, {double? yaw}) {
  final tuned = tuneFaceForSpecies(base.preset, base.faceStyle);
  final rig = composeFaceRig(base.preset, rigFor(s.emotion), s);
  return base
      .copyWithParts(poseParts(base.parts, rig))
      .copyWith(
        faceStyle: expressFace(tuned, s.emotion).withEyeOpenness(1 - s.blink),
        viewState: base.viewState.copyWith(
          yaw: yaw ?? s.headTurn.dx * .3,
          pitch: s.headTurn.dy * .21 + rig.pitch,
          roll: s.tilt + rig.browAsym * .065,
        ),
      );
}

void draw(
  ui.Canvas canvas,
  AvatarScene base,
  PetBehaviorSnapshot s,
  int size, {
  double? yaw,
  ui.Color? background,
  bool silhouette = false,
}) {
  final scene = resolve(base, s, yaw: yaw);
  final geometry = buildAvatarGeometry(
    scene,
    densityScale: avatarDensityFor(size.toDouble()),
  );
  final rest = buildAvatarGeometry(
    resolve(base, const PetBehaviorSnapshot()),
    densityScale: .5,
  ).bounds;
  canvas.save();
  canvas.translate(
    s.bodyLean.dx * size * .03,
    (s.bounce / 220) * size + s.breath * size * .004,
  );
  final squash = s.squash.clamp(.92, 1.10);
  canvas.translate(size / 2, size / 2);
  canvas.scale(math.sqrt(squash), 1 / squash);
  canvas.translate(-size / 2, -size / 2);
  if (silhouette) {
    final scale = size / (math.max(rest.width, rest.height) * 1.18);
    canvas.translate(size / 2, size / 2);
    canvas.scale(scale);
    canvas.translate(-rest.center.dx, -rest.center.dy);
    for (final p in geometry.parts) {
      canvas.drawPath(
        p.outline,
        ui.Paint()..color = const ui.Color(0xff24272a),
      );
    }
  } else {
    AvatarScenePainter(
      geometry: geometry,
      scene: scene,
      fitBounds: rest,
      background: background,
      gaze: s.gaze,
      rig: composeFaceRig(base.preset, rigFor(s.emotion), s),
      blush: blushFor(s.emotion),
      showOutline: true,
    ).paint(canvas, ui.Size.square(size.toDouble()));
  }
  canvas.restore();
}

Future<void> save(
  String name,
  ui.PictureRecorder recorder,
  int w,
  int h,
) async {
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$output/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

Future<void> sheet(
  String name,
  List<AvatarScene> rows,
  List<String> cols,
  PetBehaviorSnapshot Function(int c) snapshot, {
  List<double>? angles,
  bool silhouette = false,
  int size = 128,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (!silhouette) {
    canvas.drawColor(const ui.Color(0xffece9e2), ui.BlendMode.src);
  }
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < cols.length; c++) {
      canvas.save();
      canvas.translate(c * size.toDouble(), r * size.toDouble());
      draw(
        canvas,
        rows[r],
        snapshot(c),
        size,
        yaw: angles?[c],
        silhouette: silhouette,
      );
      canvas.restore();
    }
  }
  await save(name, recorder, cols.length * size, rows.length * size);
  await File('$output/$name.txt').writeAsString(
    'rows (top to bottom): ${rows.map((e) => e.preset).join(', ')}\ncols (left to right): ${cols.join(', ')}\n',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('foundation design gate', () async {
    await AvatarSceneCatalog.instance.load();
    final scenes = foundation
        .map((s) => AvatarSceneCatalog.instance.sceneFor(s)!)
        .toList();
    await sheet(
      'foundation_views',
      scenes,
      ['front', 'three-quarter', 'side'],
      (_) => const PetBehaviorSnapshot(),
      angles: [0, .65, 1.35],
      size: 256,
    );
    await sheet(
      'foundation_emotions',
      scenes,
      PetEmotion.values.map((e) => e.name).toList(),
      (c) => PetBehaviorSnapshot(
        emotion: PetEmotionState(emotion: PetEmotion.values[c], intensity: 1),
      ),
    );
  });
  test('cute sheep and parrot shape gate', () async {
    await AvatarSceneCatalog.instance.load();
    final focus = [
      'sheep',
      'parrot',
    ].map((s) => AvatarSceneCatalog.instance.sceneFor(s)!).toList();
    await sheet(
      'cute_focus_views',
      focus,
      ['front', 'three-quarter', 'side'],
      (_) => const PetBehaviorSnapshot(),
      angles: [0, .65, 1.35],
      size: 256,
    );
  });
  test('alpaca silhouette and framing review', () async {
    await AvatarSceneCatalog.instance.load();
    final alpaca = AvatarSceneCatalog.instance.sceneFor('alpaca')!;
    await sheet(
      'alpaca_views',
      [alpaca],
      ['front', 'three-quarter', 'side'],
      (_) => const PetBehaviorSnapshot(),
      angles: [0, .65, 1.35],
      size: 256,
    );
    await sheet(
      'alpaca_poses',
      [alpaca],
      poses.keys.toList(),
      (c) => poses.values.elementAt(c),
      size: 128,
    );
    for (final size in [32, 48, 64, 96, 128, 256]) {
      final recorder = ui.PictureRecorder();
      draw(
        ui.Canvas(recorder),
        alpaca,
        const PetBehaviorSnapshot(),
        size,
        background: const ui.Color(0xffece9e2),
      );
      await save('neutral/alpaca/${size}_light', recorder, size, size);
    }
  });
  test(
    'complete native validation exports',
    () async {
      if (Platform.environment['PET_COMPLETE_EXPORT'] != '1') return;
      await AvatarSceneCatalog.instance.load();
      final scenes = AvatarSpecies.values
          .map(
            (s) =>
                AvatarSceneCatalog.instance.sceneFor(avatarPresetFor(s.name)),
          )
          .whereType<AvatarScene>()
          .toList();
      expect(scenes.length, 32);
      await sheet(
        'all_views',
        scenes,
        ['front', 'three-quarter', 'side'],
        (_) => const PetBehaviorSnapshot(),
        angles: [0, .65, 1.35],
      );
      await sheet(
        'silhouettes',
        scenes,
        ['front', 'three-quarter', 'side'],
        (_) => const PetBehaviorSnapshot(),
        angles: [0, .65, 1.35],
        silhouette: true,
      );
      await sheet(
        'all_emotions',
        scenes,
        PetEmotion.values.map((e) => e.name).toList(),
        (c) => PetBehaviorSnapshot(
          emotion: PetEmotionState(emotion: PetEmotion.values[c], intensity: 1),
        ),
      );
      await sheet(
        'all_poses',
        scenes,
        poses.keys.toList(),
        (c) => poses.values.elementAt(c),
      );
      await sheet(
        'all_activities',
        scenes,
        PetActivity.values.map((e) => e.name).toList(),
        (c) {
          final a = PetActivity.values[c];
          return PetBehaviorSnapshot(
            activity: a,
            blink: a == PetActivity.sleeping
                ? 1
                : a == PetActivity.drowsy
                ? .6
                : 0,
            emotion: PetEmotionState(
              emotion: switch (a) {
                PetActivity.sleeping || PetActivity.drowsy => PetEmotion.sleepy,
                PetActivity.curious ||
                PetActivity.watching => PetEmotion.curious,
                PetActivity.playful => PetEmotion.playful,
                PetActivity.startled => PetEmotion.startled,
                PetActivity.delighted => PetEmotion.excited,
                PetActivity.dizzy => PetEmotion.dizzy,
                PetActivity.idle => PetEmotion.content,
              },
              intensity: 1,
            ),
          );
        },
      );
      for (final scene in scenes) {
        for (final size in [32, 48, 64, 96, 128, 256]) {
          for (final mode in ['transparent', 'light', 'dark']) {
            final rec = ui.PictureRecorder();
            final canvas = ui.Canvas(rec);
            draw(
              canvas,
              scene,
              const PetBehaviorSnapshot(),
              size,
              background: switch (mode) {
                'light' => const ui.Color(0xfff1eee8),
                'dark' => const ui.Color(0xff202328),
                _ => null,
              },
            );
            await save(
              'neutral/${scene.preset}/${size}_$mode',
              rec,
              size,
              size,
            );
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
