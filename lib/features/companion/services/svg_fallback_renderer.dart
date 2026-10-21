import 'dart:developer' as developer;
import 'package:breakmate/features/companion/domain/pet_renderer_capabilities.dart';
import 'package:breakmate/features/companion/services/pet_renderer.dart';

/// Fallback SVG renderer if 3D initialization fails
class SvgFallbackRenderer implements PetRenderer {
  bool _initialized = false;
  String? _currentPetId;
  String? get currentPetId => _currentPetId;

  @override
  PetRendererCapabilities get capabilities => PetRendererCapabilities.svgFallback;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    developer.log(
      'PetRenderer: 3D initialization failed or requested fallback. Falling back to SVG renderer',
      name: 'SvgFallbackRenderer',
    );
    _initialized = true;
  }

  @override
  Future<void> loadPet(String petId) async {
    _currentPetId = petId;
  }

  @override
  void setCamera({double? azimuth, double? elevation, double? distance}) {}

  @override
  void rotate(double deltaX, double deltaY) {}

  @override
  void zoom(double delta) {}

  @override
  void playAnimation(String animation) {}

  @override
  void setExpression(String expression) {}

  @override
  void dispose() {
    _initialized = false;
  }
}
