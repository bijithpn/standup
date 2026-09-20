import 'package:blobatar_flutter/blobatar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/presentation/widgets/pet_stage.dart';
import 'package:breakmate/features/companion/render/avatar_artwork.dart';

void main() {
  Future<void> pumpStage(
    WidgetTester tester, {
    PetBehaviorSnapshot snapshot = const PetBehaviorSnapshot(),
    AvatarDefinition? definition,
    String? blobName,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PetStage(
              snapshot: snapshot,
              size: 200,
              definition: definition,
              blobName: blobName,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('PetStage', () {
    testWidgets('draws the generative blob when a name is given',
        (tester) async {
      await pumpStage(tester, blobName: 'Bubbles');

      expect(find.byType(Blobatar), findsOneWidget);
      expect(find.byType(AvatarArtwork), findsNothing);
    });

    testWidgets('the blob wins over a definition, so a blob companion is '
        'never replaced by stock artwork', (tester) async {
      await pumpStage(
        tester,
        blobName: 'Bubbles',
        definition: AvatarDefinition.fromSpecies(AvatarSpecies.cat),
      );

      expect(find.byType(Blobatar), findsOneWidget);
      expect(find.byType(AvatarArtwork), findsNothing);
    });

    testWidgets('a blank blob name falls back to the artwork', (tester) async {
      await pumpStage(
        tester,
        blobName: '   ',
        definition: AvatarDefinition.fromSpecies(AvatarSpecies.cat),
      );

      expect(find.byType(Blobatar), findsNothing);
      expect(find.byType(AvatarArtwork), findsOneWidget);
    });

    testWidgets('draws the illustrated companion from a definition',
        (tester) async {
      await pumpStage(
        tester,
        definition: AvatarDefinition.fromSpecies(AvatarSpecies.fox),
      );

      expect(find.byType(AvatarArtwork), findsOneWidget);
    });

    testWidgets('renaming the blob rebuilds it under the new name',
        (tester) async {
      await pumpStage(tester, blobName: 'Bubbles');
      expect(
        tester.widget<Blobatar>(find.byType(Blobatar)).name,
        'Bubbles',
      );

      await pumpStage(tester, blobName: 'Cosmo');
      expect(
        tester.widget<Blobatar>(find.byType(Blobatar)).name,
        'Cosmo',
      );
    });

    testWidgets('a closed-eyed snapshot squeezes the blob\'s eyes shut',
        (tester) async {
      await pumpStage(tester, blobName: 'Bubbles');
      final open = tester.widget<Blobatar>(find.byType(Blobatar)).expression;

      await pumpStage(
        tester,
        blobName: 'Bubbles',
        snapshot: const PetBehaviorSnapshot(blink: 1.0),
      );
      final shut = tester.widget<Blobatar>(find.byType(Blobatar)).expression;

      expect(shut.pose.esy, lessThan(open.pose.esy));
    });

    testWidgets('runs its own motion off the behaviour snapshot, not a second '
        'ticker', (tester) async {
      await pumpStage(tester, blobName: 'Bubbles');

      expect(
        tester.widget<Blobatar>(find.byType(Blobatar)).animate,
        BlobatarAnimate.none,
      );
    });

    testWidgets('is tappable when a handler is given', (tester) async {
      var taps = 0;
      await pumpStage(tester, blobName: 'Bubbles', onTap: () => taps++);

      await tester.tap(find.byType(PetStage));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('renders every species without throwing', (tester) async {
      for (final species in AvatarSpecies.values) {
        await pumpStage(
          tester,
          definition: AvatarDefinition.fromSpecies(species),
        );
        expect(find.byType(AvatarArtwork), findsOneWidget);
      }
    });
  });
}
