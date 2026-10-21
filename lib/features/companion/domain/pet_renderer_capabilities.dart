/// Declares the platform capabilities supported by a companion renderer.
class PetRendererCapabilities {
  final bool supports3D;
  final bool supportsTransparency;
  final bool supportsAnimation;
  final bool supportsEditor;
  final bool supportsTouchRotation;
  final bool isFallback;

  const PetRendererCapabilities({
    required this.supports3D,
    required this.supportsTransparency,
    required this.supportsAnimation,
    required this.supportsEditor,
    required this.supportsTouchRotation,
    this.isFallback = false,
  });

  static const PetRendererCapabilities native3D = PetRendererCapabilities(
    supports3D: true,
    supportsTransparency: true,
    supportsAnimation: true,
    supportsEditor: true,
    supportsTouchRotation: true,
    isFallback: false,
  );

  static const PetRendererCapabilities svgFallback = PetRendererCapabilities(
    supports3D: false,
    supportsTransparency: true,
    supportsAnimation: true,
    supportsEditor: false,
    supportsTouchRotation: false,
    isFallback: true,
  );
}
