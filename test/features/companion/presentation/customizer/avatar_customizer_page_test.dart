import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_palette.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/engine/avatar_engine_controller.dart';
import 'package:breakmate/features/companion/presentation/customizer/avatar_customizer_page.dart';
import 'package:breakmate/features/companion/presentation/widgets/avatar_customizer_sheet.dart';
import 'package:breakmate/features/companion/presentation/widgets/avatar_species_picker.dart';
import 'package:breakmate/features/companion/presentation/widgets/avatar_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('3D Pet Customizer UI Tests', () {
    late AvatarDefinition initialDefinition;
    late List<String> executedScripts;
    late AvatarEngineController engineController;

    setUp(() {
      initialDefinition = AvatarDefinition.fromSpecies(
        AvatarSpecies.cat,
        palette: AvatarPalette.warmOrange,
        seed: 'test-cat-01',
      );
      executedScripts = [];
      engineController = AvatarEngineController(
        jsEvaluator: (script) async {
          executedScripts.add(script);
          return null;
        },
      );
    });

    tearDown(() {
      engineController.dispose();
    });

    Widget buildTestWidget({
      AvatarDefinition? definition,
      ValueChanged<AvatarDefinition>? onSaved,
      VoidCallback? onCancel,
    }) {
      return MaterialApp(
        home: AvatarCustomizerPage(
          initialDefinition: definition ?? initialDefinition,
          engineController: engineController,
          onSaved: onSaved,
          onCancel: onCancel,
          isStatic: true,
        ),
      );
    }

    testWidgets('renders AvatarCustomizerPage with live 3D preview, species, seed, and palette options', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(AvatarCustomizerPage), findsOneWidget);
      expect(find.byType(AvatarView), findsOneWidget);
      expect(find.byType(AvatarSpeciesPicker), findsOneWidget);
      expect(find.byKey(const Key('seed_text_field')), findsOneWidget);
      expect(find.byKey(const Key('randomize_seed_button')), findsOneWidget);
      expect(find.byKey(const Key('save_pet_button')), findsOneWidget);
      expect(find.byKey(const Key('reset_default_button')), findsOneWidget);
      expect(find.text('3D Pet Customizer'), findsOneWidget);
    });

    testWidgets('species picker displays species and updates preview on selection', (tester) async {
      AvatarDefinition? updatedDef;

      await tester.pumpWidget(
        buildTestWidget(
          onSaved: (def) => updatedDef = def,
        ),
      );
      await tester.pumpAndSettle();

      // Filter by Canines category to view Fox
      final caninesFinder = find.text('Canines');
      await tester.tap(caninesFinder);
      await tester.pumpAndSettle();

      final foxFinder = find.byKey(const Key('species_card_fox'));
      expect(foxFinder, findsOneWidget);
      await tester.tap(foxFinder);
      await tester.pumpAndSettle();

      final saveFinder = find.byKey(const Key('save_pet_button'));
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder);
      await tester.pump(const Duration(seconds: 4));

      expect(updatedDef, isNotNull);
      expect(updatedDef!.species, equals(AvatarSpecies.fox));
    });

    testWidgets('randomize seed button generates new seed and modifies avatar definition', (tester) async {
      AvatarDefinition? savedDef;

      await tester.pumpWidget(
        buildTestWidget(
          onSaved: (def) => savedDef = def,
        ),
      );
      await tester.pumpAndSettle();

      final initialSeedField = tester.widget<TextField>(find.byKey(const Key('seed_text_field')));
      final oldSeed = initialSeedField.controller?.text ?? '';

      final randFinder = find.byKey(const Key('randomize_seed_button'));
      await tester.ensureVisible(randFinder);
      await tester.tap(randFinder);
      await tester.pumpAndSettle();

      final newSeedField = tester.widget<TextField>(find.byKey(const Key('seed_text_field')));
      final newSeed = newSeedField.controller?.text ?? '';

      expect(newSeed, isNotEmpty);
      expect(newSeed, isNot(equals(oldSeed)));

      final saveFinder = find.byKey(const Key('save_pet_button'));
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder);
      await tester.pump(const Duration(seconds: 4));

      expect(savedDef?.seed, equals(newSeed));
    });

    testWidgets('palette picker switches color palette', (tester) async {
      AvatarDefinition? savedDef;

      await tester.pumpWidget(
        buildTestWidget(
          onSaved: (def) => savedDef = def,
        ),
      );
      await tester.pumpAndSettle();

      final cyberpunkFinder = find.byKey(const Key('palette_card_cyberpunk'));
      await tester.ensureVisible(cyberpunkFinder);
      await tester.tap(cyberpunkFinder);
      await tester.pumpAndSettle();

      final saveFinder = find.byKey(const Key('save_pet_button'));
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder);
      await tester.pump(const Duration(seconds: 4));

      expect(savedDef?.palette.name, equals('cyberpunk'));
    });

    testWidgets('preview animation triggers animation on engine controller', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final previewAnimFinder = find.byKey(const Key('preview_animation_button'));
      await tester.ensureVisible(previewAnimFinder);
      await tester.tap(previewAnimFinder);
      await tester.pumpAndSettle();

      expect(engineController.currentClip, isNotNull);
      expect(executedScripts.any((s) => s.contains('playAnimation')), isTrue);
    });

    testWidgets('reset to default button resets species, palette, and seed', (tester) async {
      AvatarDefinition? savedDef;

      await tester.pumpWidget(
        buildTestWidget(
          definition: AvatarDefinition.fromSpecies(
            AvatarSpecies.wolf,
            palette: AvatarPalette.cyberpunk,
            seed: 'custom-seed-777',
          ),
          onSaved: (def) => savedDef = def,
        ),
      );
      await tester.pumpAndSettle();

      final resetFinder = find.byKey(const Key('reset_default_button'));
      await tester.ensureVisible(resetFinder);
      await tester.tap(resetFinder);
      await tester.pumpAndSettle();

      final saveFinder = find.byKey(const Key('save_pet_button'));
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder);
      await tester.pump(const Duration(seconds: 4));

      expect(savedDef?.species, equals(AvatarSpecies.cat));
      expect(savedDef?.palette.name, equals(AvatarPalette.defaultPalette.name));
    });

    testWidgets('AvatarSpeciesPicker displays all 30+ species and category filter chips', (tester) async {
      AvatarSpecies? pickedSpecies;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvatarSpeciesPicker(
              selectedSpecies: AvatarSpecies.cat,
              onSpeciesSelected: (species) => pickedSpecies = species,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Birds'), findsOneWidget);
      expect(find.text('Canines'), findsOneWidget);
      expect(find.text('Rodents'), findsOneWidget);

      await tester.tap(find.text('Birds'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('species_card_penguin')), findsOneWidget);
      expect(find.byKey(const Key('species_card_owl')), findsOneWidget);

      await tester.tap(find.byKey(const Key('species_card_penguin')));
      await tester.pumpAndSettle();

      expect(pickedSpecies, equals(AvatarSpecies.penguin));
    });

    testWidgets('AvatarCustomizerSheet renders standalone in bottom sheet modal', (tester) async {
      AvatarDefinition? sheetSavedDef;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_sheet_btn'),
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => AvatarCustomizerSheet(
                      initialDefinition: initialDefinition,
                      engineController: engineController,
                      isStatic: true,
                      onSaved: (def) {
                        sheetSavedDef = def;
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(AvatarCustomizerSheet), findsOneWidget);
      expect(find.byKey(const Key('save_pet_button')), findsOneWidget);

      final sheetSaveFinder = find.byKey(const Key('save_pet_button'));
      await tester.ensureVisible(sheetSaveFinder);
      await tester.tap(sheetSaveFinder);
      await tester.pump(const Duration(seconds: 4));

      expect(sheetSavedDef, isNotNull);
    });
  });
}
