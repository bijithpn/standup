import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/avatar3d/species_face.dart';

void main() {
  const base = AvatarFaceStyle();

  test('different species get different eyes', () {
    final bear = tuneFaceForSpecies('bear', base);
    final owl = tuneFaceForSpecies('owl', base);
    final rabbit = tuneFaceForSpecies('rabbit', base);
    expect(owl.width, greaterThan(bear.width));
    expect(rabbit.height, greaterThan(bear.height));
    expect(tuneFaceForSpecies('ferret', base).gap, lessThan(bear.gap));
  });

  test('an unknown species keeps its authored face', () {
    expect(tuneFaceForSpecies('dragon', base), same(base));
  });

  test('tilt mirrors across the two eyes', () {
    final fox = tuneFaceForSpecies('fox', base);
    expect(fox.leftEyeRotation, -fox.rightEyeRotation);
    expect(fox.leftEyeRotation, isNot(0));
  });

  test('birds have no nose of their own', () {
    expect(tuneFaceForSpecies('duck', base).noseEnabled, isFalse);
    expect(tuneFaceForSpecies('dog', base).noseEnabled, isTrue);
  });
}
