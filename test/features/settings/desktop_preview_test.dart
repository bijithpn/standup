import 'dart:io';
import 'dart:ui' as ui;

import 'package:breakmate/features/break_overlay/wellness/wellness_registry.dart';
import 'package:breakmate/features/settings/widgets/menu_bar_mode_picker.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final snapshotKey = GlobalKey();
  setUpAll(() async {
    final fonts = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter/Inter-Regular.ttf'));
    await fonts.load();
    final mono = FontLoader('JetBrains Mono')
      ..addFont(
        rootBundle.load('assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf'),
      );
    await mono.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    final output = Platform.environment['DESKTOP_PREVIEW_DIR'];
    if (output == null) return;
    await tester.pump();
    final boundary =
        snapshotKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final compact in [true, false]) {
    testWidgets(
      'all six ${compact ? "compact" : "immersive"} gallery previews settle',
      (tester) async {
        tester.view.physicalSize = const Size(760, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.materialTheme,
            builder: (_, child) =>
                RepaintBoundary(key: snapshotKey, child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 16,
                    children: [
                      for (final template in wellnessTemplates)
                        SizedBox(
                          width: 340,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 340,
                                height: 190,
                                child: ClipRect(
                                  child: ColoredBox(
                                    color: template.palette.canvas,
                                    child: compact
                                        ? template.preview(
                                            context,
                                            compact: true,
                                          )
                                        : FittedBox(
                                            child: SizedBox(
                                              width: 1280,
                                              height: 720,
                                              child: template.preview(
                                                context,
                                                compact: false,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(template.name),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final template in wellnessTemplates) {
          expect(find.text(template.name), findsOneWidget);
        }
        await capture(
          tester,
          compact ? 'templates-compact' : 'templates-immersive',
        );
      },
    );
  }

  testWidgets('all menu bar previews render with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.materialTheme,
        builder: (_, child) => RepaintBoundary(key: snapshotKey, child: child!),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              disableAnimations: true,
            ),
            child: Center(
              child: MenuBarModePicker(
                modes: const {
                  'companion': 'Companion',
                  'progress': 'Progress',
                  'focusdot': 'Focus dot',
                  'countdown': 'Countdown',
                  'minimal': 'Minimal',
                },
                selected: 'countdown',
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Countdown'), findsOneWidget);
    await capture(tester, 'menu-bar');
  });
}
