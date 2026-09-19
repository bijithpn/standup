import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/avatar_definition.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';
import 'package:breakmate/features/companion/presentation/customizer/avatar_customizer_page.dart';

void main() {
  group('AvatarCustomizerPage with 3D controls', () {
    testWidgets('renders 3D customizer with Species, Colors, Camera, and Seed tabs', (tester) async {
      final definition = AvatarDefinition.fromSpecies(AvatarSpecies.cat);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvatarCustomizerPage(
              initialDefinition: definition,
              isStatic: true,
            ),
          ),
        ),
      );

      // Verify tabs exist
      expect(find.text('Species'), findsOneWidget);
      expect(find.text('Colors'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Seed'), findsOneWidget);

      // Tap Camera tab
      await tester.tap(find.text('Camera'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify 3D Camera controls are visible
      expect(find.text('3D ORBIT CAMERA'), findsOneWidget);
      expect(find.text('Azimuth (Yaw)'), findsOneWidget);
      expect(find.text('Elevation (Pitch)'), findsOneWidget);
      expect(find.text('Reset 3D Camera'), findsOneWidget);
    });
  });
}
