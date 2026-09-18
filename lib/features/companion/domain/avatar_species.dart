enum AvatarSpeciesCategory {
  feline('Felines'),
  canine('Canines'),
  rodent('Rodents'),
  avian('Birds'),
  farm('Farm Animals'),
  wildlife('Wildlife'),
  aquatic('Aquatics');

  final String displayName;
  const AvatarSpeciesCategory(this.displayName);
}

enum AvatarSpecies {
  alpaca(
    displayName: 'Alpaca',
    category: AvatarSpeciesCategory.farm,
    defaultPartConfigurations: {'hasLongNeck': true, 'hasFluffyBody': true},
  ),
  beaver(
    displayName: 'Beaver',
    category: AvatarSpeciesCategory.rodent,
    defaultPartConfigurations: {'hasFlatTail': true, 'hasBuckTeeth': true},
  ),
  capybara(
    displayName: 'Capybara',
    category: AvatarSpeciesCategory.rodent,
    defaultPartConfigurations: {'hasSquareSnout': true, 'hasShortEars': true},
  ),
  cat(
    displayName: 'Cat',
    category: AvatarSpeciesCategory.feline,
    defaultPartConfigurations: {'hasPointyEars': true, 'hasLongTail': true, 'hasWhiskers': true},
  ),
  chinchilla(
    displayName: 'Chinchilla',
    category: AvatarSpeciesCategory.rodent,
    defaultPartConfigurations: {'hasRoundEars': true, 'hasBushyTail': true},
  ),
  chick(
    displayName: 'Chick',
    category: AvatarSpeciesCategory.avian,
    defaultPartConfigurations: {'hasBeak': true, 'hasWings': true, 'hasSmallTail': true},
  ),
  cow(
    displayName: 'Cow',
    category: AvatarSpeciesCategory.farm,
    defaultPartConfigurations: {'hasHorns': true, 'hasSnout': true},
  ),
  dog(
    displayName: 'Dog',
    category: AvatarSpeciesCategory.canine,
    defaultPartConfigurations: {'hasFloppyEars': true, 'hasTail': true, 'hasSnout': true},
  ),
  duck(
    displayName: 'Duck',
    category: AvatarSpeciesCategory.avian,
    defaultPartConfigurations: {'hasFlatBeak': true, 'hasWings': true, 'hasWebbedFeet': true},
  ),
  deer(
    displayName: 'Deer',
    category: AvatarSpeciesCategory.wildlife,
    defaultPartConfigurations: {'hasAntlers': true, 'hasSpottedBack': true, 'hasSlenderLegs': true},
  ),
  fox(
    displayName: 'Fox',
    category: AvatarSpeciesCategory.canine,
    defaultPartConfigurations: {'hasPointyEars': true, 'hasBushyTail': true, 'hasPointySnout': true},
  ),
  ferret(
    displayName: 'Ferret',
    category: AvatarSpeciesCategory.wildlife,
    defaultPartConfigurations: {'hasLongBody': true, 'hasShortLegs': true, 'hasMask': true},
  ),
  guineaPig(
    displayName: 'Guinea Pig',
    category: AvatarSpeciesCategory.rodent,
    defaultPartConfigurations: {'hasRoundBody': true, 'hasNoTail': true},
  ),
  goose(
    displayName: 'Goose',
    category: AvatarSpeciesCategory.avian,
    defaultPartConfigurations: {'hasLongNeck': true, 'hasOrangeBeak': true, 'hasWings': true},
  ),
  hamster(
    displayName: 'Hamster',
    category: AvatarSpeciesCategory.rodent,
    defaultPartConfigurations: {'hasCheekPouches': true, 'hasShortTail': true},
  ),
  hedgehog(
    displayName: 'Hedgehog',
    category: AvatarSpeciesCategory.rodent,
    defaultPartConfigurations: {'hasQuills': true, 'hasSmallSnout': true},
  ),
  lion(
    displayName: 'Lion',
    category: AvatarSpeciesCategory.feline,
    defaultPartConfigurations: {'hasMane': true, 'hasTuftedTail': true},
  ),
  monkey(
    displayName: 'Monkey',
    category: AvatarSpeciesCategory.wildlife,
    defaultPartConfigurations: {'hasCurledTail': true, 'hasRoundEars': true},
  ),
  otter(
    displayName: 'Otter',
    category: AvatarSpeciesCategory.aquatic,
    defaultPartConfigurations: {'hasSleekBody': true, 'hasWebbedPaws': true, 'hasTaperedTail': true},
  ),
  owl(
    displayName: 'Owl',
    category: AvatarSpeciesCategory.avian,
    defaultPartConfigurations: {'hasBeak': true, 'hasWings': true, 'hasBigEyes': true, 'hasEarTufts': true},
  ),
  parrot(
    displayName: 'Parrot',
    category: AvatarSpeciesCategory.avian,
    defaultPartConfigurations: {'hasCurvedBeak': true, 'hasWings': true, 'hasColorfulCrest': true},
  ),
  pig(
    displayName: 'Pig',
    category: AvatarSpeciesCategory.farm,
    defaultPartConfigurations: {'hasCurlyTail': true, 'hasSnout': true},
  ),
  panda(
    displayName: 'Panda',
    category: AvatarSpeciesCategory.wildlife,
    defaultPartConfigurations: {'hasEyePatches': true, 'hasRoundEars': true},
  ),
  penguin(
    displayName: 'Penguin',
    category: AvatarSpeciesCategory.avian,
    defaultPartConfigurations: {'hasFlippers': true, 'hasBeak': true, 'hasWhiteBelly': true},
  ),
  rabbit(
    displayName: 'Rabbit',
    category: AvatarSpeciesCategory.wildlife,
    defaultPartConfigurations: {'hasLongEars': true, 'hasCottonTail': true},
  ),
  redPanda(
    displayName: 'Red Panda',
    category: AvatarSpeciesCategory.wildlife,
    defaultPartConfigurations: {'hasRingedTail': true, 'hasWhiteFaceMarks': true},
  ),
  raccoon(
    displayName: 'Raccoon',
    category: AvatarSpeciesCategory.wildlife,
    defaultPartConfigurations: {'hasBanditMask': true, 'hasRingedTail': true},
  ),
  sheep(
    displayName: 'Sheep',
    category: AvatarSpeciesCategory.farm,
    defaultPartConfigurations: {'hasWoollyCoat': true, 'hasFloppyEars': true},
  ),
  seal(
    displayName: 'Seal',
    category: AvatarSpeciesCategory.aquatic,
    defaultPartConfigurations: {'hasFlippers': true, 'hasRoundBody': true, 'hasWhiskers': true},
  ),
  squirrel(
    displayName: 'Squirrel',
    category: AvatarSpeciesCategory.rodent,
    defaultPartConfigurations: {'hasBigBushyTail': true, 'hasSmallHands': true},
  ),
  tiger(
    displayName: 'Tiger',
    category: AvatarSpeciesCategory.feline,
    defaultPartConfigurations: {'hasStripes': true, 'hasLongTail': true, 'hasRoundEars': true},
  ),
  wolf(
    displayName: 'Wolf',
    category: AvatarSpeciesCategory.canine,
    defaultPartConfigurations: {'hasPointyEars': true, 'hasLongMuzzle': true, 'hasBushyTail': true},
  ),
  bear(
    displayName: 'Bear',
    category: AvatarSpeciesCategory.wildlife,
    defaultPartConfigurations: {'hasRoundEars': true, 'hasSturdyBody': true, 'hasShortTail': true},
  );

  final String displayName;
  final AvatarSpeciesCategory category;
  final Map<String, dynamic> defaultPartConfigurations;

  const AvatarSpecies({
    required this.displayName,
    required this.category,
    required this.defaultPartConfigurations,
  });

  static AvatarSpecies fromName(String name) {
    return AvatarSpecies.values.firstWhere(
      (s) => s.name == name || s.name.toLowerCase() == name.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown AvatarSpecies name: $name'),
    );
  }

  static AvatarSpecies? tryParse(String? name) {
    if (name == null || name.isEmpty) return null;
    try {
      return AvatarSpecies.values.firstWhere(
        (s) => s.name == name || s.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  bool get isAvian => category == AvatarSpeciesCategory.avian;
  bool get isAquatic => category == AvatarSpeciesCategory.aquatic;
  bool get isFeline => category == AvatarSpeciesCategory.feline;
  bool get isCanine => category == AvatarSpeciesCategory.canine;
  bool get isRodent => category == AvatarSpeciesCategory.rodent;

  String get svgAssetPath {
    switch (this) {
      case AvatarSpecies.guineaPig:
        return 'assets/avatars/species/guinea-pig.svg';
      case AvatarSpecies.panda:
        return 'assets/avatars/breeds/bear--giant-panda.svg';
      case AvatarSpecies.redPanda:
        return 'assets/avatars/breeds/bear--red-panda.svg';
      case AvatarSpecies.raccoon:
        return 'assets/avatars/breeds/bear--raccoon.svg';
      case AvatarSpecies.wolf:
        return 'assets/avatars/breeds/dog--husky.svg';
      default:
        return 'assets/avatars/species/$name.svg';
    }
  }
}
