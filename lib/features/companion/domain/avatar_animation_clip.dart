enum AvatarAnimationClip {
  idle(
    displayName: 'Idle',
    duration: Duration(milliseconds: 2000),
    isLooping: true,
  ),
  nod(
    displayName: 'Nod',
    duration: Duration(milliseconds: 1000),
    isLooping: false,
  ),
  glance(
    displayName: 'Glance',
    duration: Duration(milliseconds: 1200),
    isLooping: false,
  ),
  lookAround(
    displayName: 'Look Around',
    duration: Duration(milliseconds: 3000),
    isLooping: true,
  ),
  walk(
    displayName: 'Walk',
    duration: Duration(milliseconds: 800),
    isLooping: true,
  ),
  run(
    displayName: 'Run',
    duration: Duration(milliseconds: 500),
    isLooping: true,
  ),
  sleep(
    displayName: 'Sleep',
    duration: Duration(milliseconds: 3500),
    isLooping: true,
  ),
  blink(
    displayName: 'Blink',
    duration: Duration(milliseconds: 250),
    isLooping: false,
  ),
  stretch(
    displayName: 'Stretch',
    duration: Duration(milliseconds: 1800),
    isLooping: false,
  ),
  celebrate(
    displayName: 'Celebrate',
    duration: Duration(milliseconds: 2000),
    isLooping: false,
  ),
  bounce(
    displayName: 'Bounce',
    duration: Duration(milliseconds: 600),
    isLooping: true,
  ),
  wiggle(
    displayName: 'Wiggle',
    duration: Duration(milliseconds: 700),
    isLooping: true,
  ),
  jump(
    displayName: 'Jump',
    duration: Duration(milliseconds: 900),
    isLooping: false,
  ),
  anger(
    displayName: 'Anger',
    duration: Duration(milliseconds: 1500),
    isLooping: false,
  ),
  happiness(
    displayName: 'Happiness',
    duration: Duration(milliseconds: 1200),
    isLooping: true,
  );

  final String displayName;
  final Duration duration;
  final bool isLooping;

  const AvatarAnimationClip({
    required this.displayName,
    required this.duration,
    required this.isLooping,
  });

  static AvatarAnimationClip fromName(String name) {
    return AvatarAnimationClip.values.firstWhere(
      (clip) =>
          clip.name == name || clip.name.toLowerCase() == name.toLowerCase(),
      orElse: () =>
          throw ArgumentError('Unknown AvatarAnimationClip name: $name'),
    );
  }

  static AvatarAnimationClip? tryParse(String? name) {
    if (name == null || name.isEmpty) return null;
    try {
      return AvatarAnimationClip.values.firstWhere(
        (clip) =>
            clip.name == name || clip.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
