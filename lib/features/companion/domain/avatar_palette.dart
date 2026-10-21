class AvatarPalette {
  final String name;
  final String primary;
  final String secondary;
  final String accent;
  final String snout;
  final String ears;
  final String eyes;
  final String belly;

  const AvatarPalette({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.snout,
    required this.ears,
    required this.eyes,
    required this.belly,
  });

  static const AvatarPalette defaultPalette = AvatarPalette(
    name: 'default',
    primary: '#e67e22',
    secondary: '#f39c12',
    accent: '#d35400',
    snout: '#fde3a7',
    ears: '#e74c3c',
    eyes: '#2c3e50',
    belly: '#fdfefe',
  );

  static const AvatarPalette warmOrange = AvatarPalette(
    name: 'warmOrange',
    primary: '#d35400',
    secondary: '#e67e22',
    accent: '#f39c12',
    snout: '#f8c291',
    ears: '#c0392b',
    eyes: '#1e272e',
    belly: '#fad390',
  );

  static const AvatarPalette coolBlue = AvatarPalette(
    name: 'coolBlue',
    primary: '#0984e3',
    secondary: '#74b9ff',
    accent: '#81ecec',
    snout: '#dff9fb',
    ears: '#00cec9',
    eyes: '#2d3436',
    belly: '#ffffff',
  );

  static const AvatarPalette pastelPink = AvatarPalette(
    name: 'pastelPink',
    primary: '#ffb8b8',
    secondary: '#ffc0cb',
    accent: '#ff9ff3',
    snout: '#fff0f5',
    ears: '#ff6b81',
    eyes: '#4a4a4a',
    belly: '#ffffff',
  );

  static const AvatarPalette vibrant = AvatarPalette(
    name: 'vibrant',
    primary: '#ff6b6b',
    secondary: '#feca57',
    accent: '#ff9ff3',
    snout: '#ffeaa7',
    ears: '#ff4757',
    eyes: '#2f3542',
    belly: '#ffffff',
  );

  static const AvatarPalette monochrome = AvatarPalette(
    name: 'monochrome',
    primary: '#2d3436',
    secondary: '#636e72',
    accent: '#b2bec3',
    snout: '#dfe6e9',
    ears: '#2d3436',
    eyes: '#000000',
    belly: '#ffffff',
  );

  static const AvatarPalette cyberpunk = AvatarPalette(
    name: 'cyberpunk',
    primary: '#00f0ff',
    secondary: '#ff003c',
    accent: '#ffe600',
    snout: '#05d9e8',
    ears: '#ff2a6d',
    eyes: '#01012b',
    belly: '#d1f7ff',
  );

  static const AvatarPalette forest = AvatarPalette(
    name: 'forest',
    primary: '#27ae60',
    secondary: '#2ecc71',
    accent: '#16a085',
    snout: '#a8e6cf',
    ears: '#1e824c',
    eyes: '#1b4332',
    belly: '#e8f8f5',
  );

  static const AvatarPalette sunset = AvatarPalette(
    name: 'sunset',
    primary: '#e17055',
    secondary: '#fdcb6e',
    accent: '#d63031',
    snout: '#ffeaa7',
    ears: '#e84393',
    eyes: '#2d3436',
    belly: '#fff5eb',
  );

  static const AvatarPalette earth = AvatarPalette(
    name: 'earth',
    primary: '#795548',
    secondary: '#8d6e63',
    accent: '#a1887f',
    snout: '#d7ccc8',
    ears: '#5d4037',
    eyes: '#3e2723',
    belly: '#efebe9',
  );

  static const AvatarPalette cosmic = AvatarPalette(
    name: 'cosmic',
    primary: '#4834d4',
    secondary: '#686de0',
    accent: '#be2edd',
    snout: '#e056fd',
    ears: '#30336b',
    eyes: '#130f40',
    belly: '#ffffff',
  );

  static const AvatarPalette pastel = AvatarPalette(
    name: 'pastel',
    primary: '#a8d8ea',
    secondary: '#aa96da',
    accent: '#fcbad3',
    snout: '#ffffd2',
    ears: '#fcbad3',
    eyes: '#4a4a4a',
    belly: '#ffffff',
  );

  static const AvatarPalette warm = AvatarPalette(
    name: 'warm',
    primary: '#d35400',
    secondary: '#e67e22',
    accent: '#f39c12',
    snout: '#f8c291',
    ears: '#c0392b',
    eyes: '#1e272e',
    belly: '#fad390',
  );

  static const AvatarPalette cool = AvatarPalette(
    name: 'cool',
    primary: '#0984e3',
    secondary: '#74b9ff',
    accent: '#81ecec',
    snout: '#dff9fb',
    ears: '#00cec9',
    eyes: '#2d3436',
    belly: '#ffffff',
  );

  static const Map<String, AvatarPalette> presets = {
    'default': defaultPalette,
    'warmOrange': warmOrange,
    'coolBlue': coolBlue,
    'pastelPink': pastelPink,
    'vibrant': vibrant,
    'monochrome': monochrome,
    'cyberpunk': cyberpunk,
    'forest': forest,
    'sunset': sunset,
    'earth': earth,
    'cosmic': cosmic,
    'pastel': pastel,
    'warm': warm,
    'cool': cool,
  };

  static AvatarPalette fromName(String name) {
    return presets[name] ??
        presets.values.firstWhere(
          (p) => p.name.toLowerCase() == name.toLowerCase(),
          orElse: () => defaultPalette,
        );
  }

  static AvatarPalette? tryParse(String? name) {
    if (name == null || name.isEmpty) return null;
    return presets[name] ??
        presets.values.cast<AvatarPalette?>().firstWhere(
          (p) => p?.name.toLowerCase() == name.toLowerCase(),
          orElse: () => null,
        );
  }

  AvatarPalette copyWith({
    String? name,
    String? primary,
    String? secondary,
    String? accent,
    String? snout,
    String? ears,
    String? eyes,
    String? belly,
  }) {
    return AvatarPalette(
      name: name ?? this.name,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      snout: snout ?? this.snout,
      ears: ears ?? this.ears,
      eyes: eyes ?? this.eyes,
      belly: belly ?? this.belly,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'primary': primary,
      'secondary': secondary,
      'accent': accent,
      'snout': snout,
      'ears': ears,
      'eyes': eyes,
      'belly': belly,
    };
  }

  factory AvatarPalette.fromJson(Map<String, dynamic> json) {
    return AvatarPalette(
      name: json['name'] as String? ?? 'custom',
      primary: json['primary'] as String? ?? defaultPalette.primary,
      secondary: json['secondary'] as String? ?? defaultPalette.secondary,
      accent: json['accent'] as String? ?? defaultPalette.accent,
      snout: json['snout'] as String? ?? defaultPalette.snout,
      ears: json['ears'] as String? ?? defaultPalette.ears,
      eyes: json['eyes'] as String? ?? defaultPalette.eyes,
      belly: json['belly'] as String? ?? defaultPalette.belly,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarPalette &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          primary == other.primary &&
          secondary == other.secondary &&
          accent == other.accent &&
          snout == other.snout &&
          ears == other.ears &&
          eyes == other.eyes &&
          belly == other.belly;

  @override
  int get hashCode => Object.hash(
        name,
        primary,
        secondary,
        accent,
        snout,
        ears,
        eyes,
        belly,
      );

  @override
  String toString() => 'AvatarPalette($name: $primary, $secondary, $accent)';
}
