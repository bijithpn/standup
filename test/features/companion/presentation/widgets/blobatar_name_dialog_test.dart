import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/presentation/widgets/blobatar_name_dialog.dart';
import 'package:blobatar_flutter/blobatar_flutter.dart';

void main() {
  group('BlobatarNameDialog', () {
    testWidgets('shows dialog with live preview and saves updated name',
        (tester) async {
      String? savedName;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showBlobatarNameDialog(
                    context,
                    currentName: 'OldName',
                    onSaved: (newName) {
                      savedName = newName;
                    },
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Name your Blobatar'), findsOneWidget);
      expect(find.byType(Blobatar), findsOneWidget);

      // Enter a new name
      await tester.enterText(find.byType(TextField), 'Pixel');
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save Name'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(savedName, equals('Pixel'));
    });

    testWidgets('clicking suggestion chip updates text field and preview',
        (tester) async {
      String? savedName;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showBlobatarNameDialog(
                    context,
                    currentName: 'OldName',
                    onSaved: (newName) {
                      savedName = newName;
                    },
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Click on a chip suggestion (e.g. "Bubbles")
      final bubblesChip = find.text('Bubbles');
      expect(bubblesChip, findsOneWidget);
      await tester.tap(bubblesChip);
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save Name'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(savedName, equals('Bubbles'));
    });

    testWidgets(
        'renders gracefully inside vertically constrained box without overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(800, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showBlobatarNameDialog(
                    context,
                    currentName: 'OldName',
                    onSaved: (_) {},
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Name your Blobatar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
