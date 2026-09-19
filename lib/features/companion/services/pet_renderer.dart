import 'package:breakmate/features/companion/domain/pet_renderer_capabilities.dart';

/// Clean interface representing a pet companion renderer.
abstract class PetRenderer {
  PetRendererCapabilities get capabilities;
  bool get isInitialized;

  Future<void> initialize();
  Future<void> loadPet(String petId);

  void setCamera({
    double? azimuth,
    double? elevation,
    double? distance,
  });

  void rotate(double deltaX, double deltaY);
  void zoom(double delta);
  void playAnimation(String animation);
  void setExpression(String expression);

  void dispose();
}
