import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_scene_style.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/presentation/customizer/avatar_customizer_page.dart';
import 'package:breakmate/features/companion/presentation/widgets/pet_stage.dart';

void main() {
  Future<void> pumpStudio(
    WidgetTester tester, {
    AvatarDefinition? definition,
    ValueChanged<AvatarDefinition>? onSaved,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AvatarCustomizerPage(
          initialDefinition:
              definition ?? AvatarDefinition.fromSpecies(AvatarSpecies.cat),
          isStatic: true,
          onSaved: onSaved,
        ),
      ),
    );
    await tester.pump();
  }

  group('Companion studio', () {
    testWidgets('shows one surface with every control section', (tester) async {
      await pumpStudio(tester);

      expect(find.text('Companion Studio'), findsOneWidget);
      expect(find.text('Species'), findsOneWidget);
      expect(find.text('Breed'), findsOneWidget);
      expect(find.text('Palette'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      expect(find.text('Seed'), findsOneWidget);
      expect(find.byType(PetStage), findsOneWidget);
    });

    testWidgets('has no 3D view mode or orbit camera controls', (tester) async {
      await pumpStudio(tester);

      // The 3D view was removed in favour of a single studio surface.
      expect(find.text('3D View'), findsNothing);
      expect(find.text('Camera'), findsNothing);
      expect(find.text('3D ORBIT CAMERA'), findsNothing);
      expect(find.text('Azimuth (Yaw)'), findsNothing);
      expect(find.textContaining('Zoom In'), findsNothing);
    });

    testWidgets('selecting a species updates the preview subtitle', (
      tester,
    ) async {
      await pumpStudio(tester);

      expect(find.textContaining('Cat'), findsWidgets);

      await tester.tap(find.text('Fox').first);
      await tester.pump();

      expect(find.textContaining('Fox'), findsWidgets);
    });

    testWidgets('switching species resets the breed to one that exists', (
      tester,
    ) async {
      AvatarDefinition? saved;
      await pumpStudio(
        tester,
        definition: AvatarDefinition.fromSpecies(
          AvatarSpecies.cat,
          breed: 'black-cat',
        ),
        onSaved: (definition) => saved = definition,
      );

      await tester.tap(find.text('Dog').first);
      await tester.pump();

      await tester.tap(find.text('Save companion'));
      await tester.pump();
      // Let the confirmation toast's own timer run out before the tree goes.
      await tester.pump(const Duration(seconds: 4));

      expect(saved, isNotNull);
      expect(saved!.species, AvatarSpecies.dog);
      expect(
        saved!.breed,
        isNot('black-cat'),
        reason: 'a cat breed cannot describe a dog',
      );
    });

    testWidgets('choosing a palette carries into the saved definition', (
      tester,
    ) async {
      AvatarDefinition? saved;
      await pumpStudio(tester, onSaved: (definition) => saved = definition);

      await tester.tap(find.text('Palette'));
      await tester.pump();

      await tester.tap(find.text('Cyberpunk'));
      await tester.pump();

      await tester.tap(find.text('Save companion'));
      await tester.pump();
      // Let the confirmation toast's own timer run out before the tree goes.
      await tester.pump(const Duration(seconds: 4));

      expect(saved, isNotNull);
      expect(saved!.palette, AvatarPalette.cyberpunk);
    });

    testWidgets('the style panel exposes the scene controls', (tester) async {
      await pumpStudio(tester);

      await tester.tap(find.text('Style'));
      await tester.pump();

      // These come from the scene data and had no way in before.
      expect(find.text('Direction'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Outline'), findsOneWidget);
      expect(find.text('Drop shadow'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Eye spacing'), findsOneWidget);
      expect(find.text('Eye sparkle'), findsOneWidget);
      expect(find.text('Nose'), findsOneWidget);
    });

    testWidgets('a style change carries into the saved definition', (
      tester,
    ) async {
      AvatarDefinition? saved;
      await pumpStudio(tester, onSaved: (definition) => saved = definition);

      await tester.tap(find.text('Style'));
      await tester.pump();

      // Outline, then drop shadow, then the two face toggles.
      await tester.tap(find.byType(Switch).at(1));
      await tester.pump();

      await tester.tap(find.text('Save companion'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      expect(saved, isNotNull);
      expect(avatarStyleFrom(saved!.parts).isAuthored, isFalse);
    });

    testWidgets('an untouched companion carries no style at all', (
      tester,
    ) async {
      AvatarDefinition? saved;
      await pumpStudio(tester, onSaved: (definition) => saved = definition);

      await tester.tap(find.text('Save companion'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      // Nothing overridden means nothing stored, so a companion made before
      // styling existed and one made now are indistinguishable.
      expect(saved, isNotNull);
      expect(avatarStyleFrom(saved!.parts).isAuthored, isTrue);
    });
  });
}
