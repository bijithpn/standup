import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/services/native_3d_renderer.dart';
import 'package:breakmate/features/companion/services/svg_fallback_renderer.dart';

void main() {
  group('PetRenderer abstraction & capabilities', () {
    test('Native3DRenderer exposes 3D capabilities and initializes', () async {
      final renderer = Native3DRenderer();
      expect(renderer.capabilities.supports3D, isTrue);
      expect(renderer.capabilities.supportsTransparency, isTrue);
      expect(renderer.capabilities.supportsTouchRotation, isTrue);

      await renderer.initialize();
      expect(renderer.isInitialized, isTrue);

      renderer.setCamera(azimuth: 45.0, elevation: 15.0, distance: 1.2);
      expect(renderer.cameraAzimuth, equals(45.0));
      expect(renderer.cameraElevation, equals(15.0));
      expect(renderer.cameraDistance, equals(1.2));

      renderer.dispose();
      expect(renderer.isInitialized, isFalse);
    });

    test('SvgFallbackRenderer initializes and logs fallback warning', () async {
      final fallbackRenderer = SvgFallbackRenderer();
      expect(fallbackRenderer.capabilities.supports3D, isFalse);
      expect(fallbackRenderer.capabilities.isFallback, isTrue);

      await fallbackRenderer.initialize();
      expect(fallbackRenderer.isInitialized, isTrue);

      fallbackRenderer.dispose();
    });
  });
}
