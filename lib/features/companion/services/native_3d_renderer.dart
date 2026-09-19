import 'package:breakmate/features/companion/domain/pet_renderer_capabilities.dart';
import 'package:breakmate/features/companion/services/pet_renderer.dart';

/// Primary Native 3D Renderer backed by Dart mathematical geometry projection
class Native3DRenderer implements PetRenderer {
  bool _initialized = false;
  double _azimuth = 0.0;
  double _elevation = 0.0;
  double _distance = 1.0;
  String? _currentPetId;
  String _currentAnimation = 'idle';
  String _currentExpression = 'neutral';

  String? get currentPetId => _currentPetId;
  String get currentAnimation => _currentAnimation;
  String get currentExpression => _currentExpression;

  double get cameraAzimuth => _azimuth;
  double get cameraElevation => _elevation;
  double get cameraDistance => _distance;

  @override
  PetRendererCapabilities get capabilities => PetRendererCapabilities.native3D;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<void> loadPet(String petId) async {
    _currentPetId = petId;
  }

  @override
  void setCamera({double? azimuth, double? elevation, double? distance}) {
    if (azimuth != null) _azimuth = azimuth;
    if (elevation != null) _elevation = elevation;
    if (distance != null) _distance = distance;
  }

  @override
  void rotate(double deltaX, double deltaY) {
    _azimuth = (_azimuth + deltaX) % 360.0;
    _elevation = (_elevation + deltaY).clamp(-45.0, 45.0);
  }

  @override
  void zoom(double delta) {
    _distance = (_distance * delta).clamp(0.5, 3.0);
  }

  @override
  void playAnimation(String animation) {
    _currentAnimation = animation;
  }

  @override
  void setExpression(String expression) {
    _currentExpression = expression;
  }

  @override
  void dispose() {
    _initialized = false;
  }
}
