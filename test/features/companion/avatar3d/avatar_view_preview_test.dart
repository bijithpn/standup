import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';

/// Renders the real [Avatar3DView] (rest pose, head turn, expression) to PNG.
///
/// Not an assertion: set `AVATAR_PREVIEW_DIR` to see what the app draws.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final outputDir = Platform.environment['AVATAR_PREVIEW_DIR'];

  Future<void> sheet(
    WidgetTester tester, {
    required String name,
    required List<String> presets,
    required List<PetBehaviorSnapshot> poses,
  }) async {
    if (outputDir == null) return;
    const cell = 200.0;
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(
      Size(cell * poses.length, cell * presets.length),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF2A2A31),
            child: Column(
              children: [
                for (final preset in presets)
                  Row(
                    children: [
                      for (final pose in poses)
                        Avatar3DView(
                          preset: preset,
                          size: cell,
                          snapshot: pose,
                          showShadow: false,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(outputDir).createSync(recursive: true);
      File('$outputDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  PetBehaviorSnapshot pose(
    PetEmotion e, {
    double intensity = 1.0,
    double look = 0.0,
    double blink = 0.0,
  }) => PetBehaviorSnapshot(
    headTurn: Offset(look, 0),
    gaze: Offset(look, 0),
    blink: blink,
    emotion: PetEmotionState(emotion: e, intensity: intensity),
  );

  testWidgets('rest pose, every species', (tester) async {
    const a = [
      'alpaca',
      'bear',
      'beaver',
      'bun',
      'capybara',
      'cat',
      'chick',
      'chinchilla',
      'cloud',
      'cow',
      'deer',
      'dog',
      'duck',
      'ferret',
      'fox',
      'goose',
    ];
    const b = [
      'guinea-pig',
      'hamster',
      'hedgehog',
      'lion',
      'monkey',
      'otter',
      'owl',
      'parrot',
      'penguin',
      'pig',
      'rabbit',
      'seal',
      'sheep',
      'squirrel',
      'sun',
      'tiger',
    ];
    final rest = [pose(PetEmotion.content, intensity: 0.5)];
    await sheet(
      tester,
      name: 'rest-a',
      presets: a.sublist(0, 8),
      poses: rest + [pose(PetEmotion.content, look: 1)],
    );
    await sheet(
      tester,
      name: 'rest-a2',
      presets: a.sublist(8),
      poses: rest + [pose(PetEmotion.content, look: 1)],
    );
    await sheet(
      tester,
      name: 'rest-b',
      presets: b.sublist(0, 8),
      poses: rest + [pose(PetEmotion.content, look: 1)],
    );
    await sheet(
      tester,
      name: 'rest-b2',
      presets: b.sublist(8),
      poses: rest + [pose(PetEmotion.content, look: 1)],
    );
  });

  testWidgets('emotions on several species', (tester) async {
    await sheet(
      tester,
      name: 'emotions-view',
      presets: const ['cat', 'dog', 'bear', 'penguin', 'rabbit'],
      poses: [for (final e in PetEmotion.values) pose(e)],
    );
  });

  testWidgets('every species, every key emotion', (tester) async {
    const all = [
      'alpaca',
      'bear',
      'beaver',
      'bun',
      'capybara',
      'cat',
      'chick',
      'chinchilla',
      'cloud',
      'cow',
      'deer',
      'dog',
      'duck',
      'ferret',
      'fox',
      'goose',
      'guinea-pig',
      'hamster',
      'hedgehog',
      'lion',
      'monkey',
      'otter',
      'owl',
      'parrot',
      'penguin',
      'pig',
      'rabbit',
      'seal',
      'sheep',
      'squirrel',
      'sun',
      'tiger',
    ];
    final poses = [
      pose(PetEmotion.content, intensity: 0.5),
      pose(PetEmotion.happy),
      pose(PetEmotion.excited),
      pose(PetEmotion.playful),
      pose(PetEmotion.laughing),
      pose(PetEmotion.startled),
      pose(PetEmotion.lonely),
      pose(PetEmotion.sleepy),
      pose(PetEmotion.content, intensity: 0.5, look: 1.0),
    ];
    for (var i = 0; i < 4; i++) {
      await sheet(
        tester,
        name: 'all-${i + 1}',
        presets: all.sublist(i * 8, i * 8 + 8),
        poses: poses,
      );
    }
  });
}
