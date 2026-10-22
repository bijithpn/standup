import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:breakmate/features/companion/domain/avatar_species.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('avatar species SVG assets exist in bundle', () async {
    for (final species in AvatarSpecies.values) {
      final svg = await rootBundle.loadString(species.svgAssetPath);
      expect(
        svg.contains('<svg'),
        isTrue,
        reason: 'Species ${species.name} SVG should be valid',
      );
    }
  });
}
