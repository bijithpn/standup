import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:breakmate/features/companion/domain/pet_theme.dart';
import 'package:breakmate/features/companion/presentation/widgets/blobatar_companion_widget.dart';
import 'package:breakmate/features/companion/presentation/widgets/blobatar_name_dialog.dart';

void main() {
  group('Blobatar Companion Integration', () {
    test('PetTheme.themes contains blobatar theme', () {
      final blobatarTheme = PetTheme.themes.firstWhere((t) => t.isBlobatar);
      expect(blobatarTheme.id, equals('blobatar'));
      expect(blobatarTheme.type, equals(PetType.blobatar));
    });

    testWidgets(
      'BlobatarCompanionWidget dynamically updates when name changes',
      (tester) async {
        String currentName = 'Bubbles';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      BlobatarCompanionWidget(
                        name: currentName,
                        size: 140,
                        animate: BlobatarAnimate.hover,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentName = 'Cosmo';
                          });
                        },
                        child: const Text('Change Name'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        final initialBlobatar = tester.widget<Blobatar>(find.byType(Blobatar));
        expect(initialBlobatar.name, equals('Bubbles'));

        // Tap button to change name
        await tester.tap(find.text('Change Name'));
        await tester.pump();

        final updatedBlobatar = tester.widget<Blobatar>(find.byType(Blobatar));
        expect(updatedBlobatar.name, equals('Cosmo'));
      },
    );

    testWidgets('Blobatar opens naming dialog on tap and saves new name', (
      tester,
    ) async {
      String companionName = 'Blobby';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return BlobatarCompanionWidget(
                  name: companionName,
                  size: 120,
                  animate: BlobatarAnimate.hover,
                  onTap: () {
                    showBlobatarNameDialog(
                      context,
                      currentName: companionName,
                      onSaved: (newName) {
                        setState(() {
                          companionName = newName;
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap the companion
      await tester.tap(find.byType(BlobatarCompanionWidget));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check dialog opened
      expect(find.text('Name your Blobatar'), findsOneWidget);

      // Pick suggestion 'Ziggy'
      final chip = find.text('Ziggy');
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pump();

      // Save
      await tester.tap(find.text('Save Name'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Companion name should now be Ziggy
      expect(companionName, equals('Ziggy'));
      final blobatar = tester.widget<Blobatar>(find.byType(Blobatar));
      expect(blobatar.name, equals('Ziggy'));
    });
  });
}
