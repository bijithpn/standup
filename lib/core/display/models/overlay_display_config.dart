enum OverlayFitMode { fill, contain, cover, adaptive }

class OverlayDisplayConfig {
  final String displayId;
  final OverlayFitMode fitMode;
  final bool isStrictMode;
  final bool ignoreSafeAreas;

  const OverlayDisplayConfig({
    required this.displayId,
    this.fitMode = OverlayFitMode.adaptive,
    this.isStrictMode = false,
    this.ignoreSafeAreas = true,
  });
}
