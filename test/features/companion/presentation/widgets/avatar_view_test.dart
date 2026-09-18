import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/avatar_animation_clip.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/engine/avatar_event_channel.dart';
import 'package:breakmate/features/companion/presentation/widgets/avatar_view.dart';
import 'package:breakmate/features/companion/services/cursor_tracker.dart';
import 'package:breakmate/core/native/native_bridge.dart';

class MockNativeBridge implements NativeBridgePlatform {
  ui.Offset currentCursor = ui.Offset.zero;

  @override
  Future<ui.Offset> getCursorPosition() async => currentCursor;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AvatarView Widget Tests', () {
    late AvatarDefinition testDefinition;
    late List<String> executedScripts;
    late AvatarEngineController controller;

    setUp(() {
      testDefinition = AvatarDefinition.fromSpecies(
        AvatarSpecies.cat,
        palette: AvatarPalette.defaultPalette,
        seed: 'test-cat-123',
      );
      executedScripts = [];
      controller = AvatarEngineController(
        jsEvaluator: (script) async {
          executedScripts.add(script);
          return null;
        },
      );
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders transparent viewport with specified size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: AvatarView(
                definition: testDefinition,
                controller: controller,
                width: 200,
                height: 180,
                isStatic: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AvatarView), findsOneWidget);
      final size = tester.getSize(find.byType(AvatarView));
      expect(size.width, equals(200));
      expect(size.height, equals(180));
    });

    testWidgets('dispatches tap event to AvatarEventChannel when tapped', (tester) async {
      final tapEvents = <AvatarTapEvent>[];
      controller.eventChannel.onTap.listen(tapEvents.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AvatarView(
                definition: testDefinition,
                controller: controller,
                width: 200,
                height: 200,
                isInteractive: true,
                isStatic: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(AvatarView));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tapEvents.length, equals(1));
    });

    testWidgets('dispatches double tap event to AvatarEventChannel when double tapped', (tester) async {
      final doubleTapEvents = <AvatarDoubleTapEvent>[];
      controller.eventChannel.onDoubleTap.listen(doubleTapEvents.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AvatarView(
                definition: testDefinition,
                controller: controller,
                width: 200,
                height: 200,
                isInteractive: true,
                isStatic: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(AvatarView));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(AvatarView));
      await tester.pump(const Duration(milliseconds: 100));

      expect(doubleTapEvents.length, equals(1));
    });

    testWidgets('updates gaze lookAt on pointer hover inside widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AvatarView(
                definition: testDefinition,
                controller: controller,
                width: 200,
                height: 200,
                autoTrackCursor: true,
                isStatic: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Hover over right side of widget
      final center = tester.getCenter(find.byType(AvatarView));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(center + const Offset(50, 0));
      await tester.pump();

      expect(executedScripts.isNotEmpty, isTrue);
      expect(executedScripts.last, contains('window.AvatarBridge.setLookAt('));
      expect(controller.currentLookAt.dx, greaterThan(0.0));
    });

    testWidgets('updates definition when widget definition property changes', (tester) async {
      final updatedDefinition = AvatarDefinition.fromSpecies(
        AvatarSpecies.fox,
        palette: AvatarPalette.warmOrange,
        seed: 'fox-seed-456',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AvatarView(
                definition: testDefinition,
                controller: controller,
                width: 200,
                height: 200,
                isStatic: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Update definition
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AvatarView(
                definition: updatedDefinition,
                controller: controller,
                width: 200,
                height: 200,
                isStatic: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(controller.currentDefinition, equals(updatedDefinition));
      expect(executedScripts.last, contains('window.AvatarBridge.setDefinition('));
      expect(executedScripts.last, contains('"fox"'));
    });

    testWidgets('supports screen-wide cursor tracking via CursorTracker', (tester) async {
      final mockBridge = MockNativeBridge();
      final cursorTracker = CursorTracker(bridge: mockBridge);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AvatarView(
                definition: testDefinition,
                controller: controller,
                cursorTracker: cursorTracker,
                autoTrackCursor: true,
                width: 200,
                height: 200,
                isStatic: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      mockBridge.currentCursor = const ui.Offset(800, 400);
      await cursorTracker.sample(0.016, const ui.Offset(400, 400));
      await tester.pump();

      expect(executedScripts.isNotEmpty, isTrue);
      expect(executedScripts.last, contains('window.AvatarBridge.setLookAt('));
      cursorTracker.dispose();
    });

    testWidgets('renders fallback vector avatar for all supported species without errors', (tester) async {
      for (final species in AvatarSpecies.values) {
        final def = AvatarDefinition.fromSpecies(
          species,
          palette: AvatarPalette.pastel,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AvatarView(
                  definition: def,
                  width: 150,
                  height: 150,
                  isStatic: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(AvatarView), findsOneWidget);
      }
    });

    testWidgets('plays animation on controller and triggers visual update', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AvatarView(
                definition: testDefinition,
                controller: controller,
                width: 200,
                height: 200,
                isStatic: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await controller.playAnimation(AvatarAnimationClip.celebrate);
      await tester.pump();

      expect(controller.currentClip, equals(AvatarAnimationClip.celebrate));
      expect(executedScripts.last, contains("window.AvatarBridge.playAnimation('celebrate'"));
    });
  });
}
