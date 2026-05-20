class AnimationRowConfig {
  final int row;
  final int frameCount;
  final double stepTime;
  final bool loop;

  const AnimationRowConfig({
    required this.row,
    required this.frameCount,
    this.stepTime = 0.1,
    this.loop = true,
  });
}
