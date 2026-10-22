import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:breakmate/features/companion/presentation/widgets/blobatar_companion_widget.dart';

void main() {
  group('BlobatarCompanionWidget', () {
    testWidgets('renders Blobatar with provided name and size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BlobatarCompanionWidget(name: 'Cosmo', size: 140),
          ),
        ),
      );

      expect(find.byType(Blobatar), findsOneWidget);
      final blobatar = tester.widget<Blobatar>(find.byType(Blobatar));
      expect(blobatar.name, equals('Cosmo'));
      expect(blobatar.size, equals(140));
    });

    testWidgets('triggers onTap and affection reaction on tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlobatarCompanionWidget(
              name: 'Mochi',
              size: 120,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(BlobatarCompanionWidget));
      await tester.pump();

      expect(tapped, isTrue);

      // Immediately after tap, expression should be loveExpression
      final blobatar = tester.widget<Blobatar>(find.byType(Blobatar));
      expect(blobatar.expression, equals(loveExpression));
    });
  });
}
