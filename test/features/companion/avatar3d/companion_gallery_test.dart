// Visual gallery: `flutter test test/features/companion/avatar3d/companion_gallery_test.dart`
// writes PNG sheets plus a .txt with row/column order to build/companion_gallery/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:breakmate/features/companion/avatar3d/avatar_3d_view.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene_catalog.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _out = 'build/companion_gallery';
const _cell = 220.0;
const _sample = [
  'cat',
  'parrot',
  'bear',
  'owl',
  'panda',
  'fox',
  'duck',
  'seal',
];

Future<void> _sheet(
  WidgetTester t,
  String name, {
  required List<String> rows,
  required List<String> cols,
  required Widget Function(String row, String col) cell,
}) async {
  final key = GlobalKey();
  await t.binding.setSurfaceSize(
    Size(cols.length * _cell, rows.length * _cell),
  );
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          backgroundColor: const Color(0xff1a1a1a),
          body: Column(
            children: [
              for (final r in rows)
                Row(
                  children: [
                    for (final c in cols)
                      SizedBox(
                        width: _cell,
                        height: _cell,
                        child: Stack(children: [cell(r, c)]),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 600));
  await t.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_out).create(recursive: true);
    await File('$_out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    await File('$_out/$name.txt').writeAsString(
      'rows (top to bottom): ${rows.join(', ')}\ncols (left to right): ${cols.join(', ')}\n',
    );
  });
}

Widget _pet(String preset, PetBehaviorSnapshot s) => Avatar3DView(
  preset: preset,
  size: _cell,
  densityScale: avatarDensityFor(_cell),
  snapshot: s,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('gallery', (t) async {
    await t.runAsync(() => AvatarSceneCatalog.instance.load());

    final species = [
      for (final s in AvatarSpecies.values)
        if (hasAvatarScene(s.name)) avatarPresetFor(s.name),
    ];
    for (var i = 0; i * 8 < species.length; i++) {
      final chunk = species.sublist(
        i * 8,
        (i * 8 + 8).clamp(0, species.length),
      );
      await _sheet(
        t,
        '1_species_$i',
        rows: ['rest'],
        cols: chunk,
        cell: (_, c) => _pet(c, const PetBehaviorSnapshot()),
      );
    }

    final emotions = {
      for (final e in PetEmotion.values)
        e.name: PetBehaviorSnapshot(
          emotion: PetEmotionState(emotion: e, intensity: 1.0),
        ),
    };
    await _sheet(
      t,
      '2_emotions',
      rows: _sample,
      cols: emotions.keys.toList(),
      cell: (r, c) => _pet(r, emotions[c]!),
    );

    const poses = {
      'left': PetBehaviorSnapshot(headTurn: Offset(-1, 0), tilt: -0.16),
      'right': PetBehaviorSnapshot(headTurn: Offset(1, 0), tilt: 0.16),
      'up': PetBehaviorSnapshot(headTurn: Offset(0, -1)),
      'down': PetBehaviorSnapshot(headTurn: Offset(0, 1)),
      'corner': PetBehaviorSnapshot(headTurn: Offset(1, 1), tilt: 0.2),
      'squash': PetBehaviorSnapshot(squash: 1.14, bounce: 12),
      'stretch': PetBehaviorSnapshot(squash: 0.9, bounce: -14),
      'lean': PetBehaviorSnapshot(bodyLean: Offset(1, 0.5)),
    };
    await _sheet(
      t,
      '3_poses',
      rows: _sample,
      cols: poses.keys.toList(),
      cell: (r, c) => _pet(r, poses[c]!),
    );

    final states = {
      for (final a in PetActivity.values)
        a.name: PetBehaviorSnapshot(
          activity: a,
          blink: a == PetActivity.sleeping
              ? 1.0
              : (a == PetActivity.drowsy ? 0.45 : 0.0),
          emotion: PetEmotionState(
            emotion: switch (a) {
              PetActivity.sleeping || PetActivity.drowsy => PetEmotion.sleepy,
              PetActivity.curious || PetActivity.watching => PetEmotion.curious,
              PetActivity.playful => PetEmotion.playful,
              PetActivity.startled => PetEmotion.startled,
              PetActivity.delighted => PetEmotion.excited,
              PetActivity.dizzy => PetEmotion.dizzy,
              PetActivity.idle => PetEmotion.content,
            },
            intensity: 0.9,
          ),
        ),
    };
    await _sheet(
      t,
      '4_activities',
      rows: _sample,
      cols: states.keys.toList(),
      cell: (r, c) => _pet(r, states[c]!),
    );

    for (final f in ['1_species_0', '2_emotions', '3_poses', '4_activities']) {
      expect(File('$_out/$f.png').existsSync(), isTrue, reason: f);
    }
  });
}
