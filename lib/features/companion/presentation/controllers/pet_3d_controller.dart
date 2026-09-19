import 'package:flutter/foundation.dart';
import 'package:breakmate/features/companion/domain/pet_animation.dart';
import 'package:breakmate/features/companion/domain/pet_camera_state.dart';
import 'package:breakmate/features/companion/domain/pet_pose.dart';

/// High-level interactive 3D Pet Controller
class Pet3DController extends ChangeNotifier {
  PetCameraState _cameraState;
  PetPose _pose;
  PetAnimation _currentAnimation = PetAnimation.idle;
  PetExpression _currentExpression = PetExpression.neutral;

  Pet3DController({
    PetCameraState initialCamera = const PetCameraState(),
    PetPose initialPose = PetPose.identity,
  })  : _cameraState = initialCamera,
        _pose = initialPose;

  PetCameraState get cameraState => _cameraState;
  PetPose get pose => _pose;
  PetAnimation get currentAnimation => _currentAnimation;
  PetExpression get currentExpression => _currentExpression;

  void rotate({required double deltaAzimuth, required double deltaElevation}) {
    final nextAzimuth = (_cameraState.azimuth + deltaAzimuth) % 360.0;
    final nextElevation = (_cameraState.elevation + deltaElevation).clamp(-45.0, 45.0);
    _cameraState = _cameraState.copyWith(
      azimuth: nextAzimuth,
      elevation: nextElevation,
    );
    notifyListeners();
  }

  void rotateTo({required double azimuth, required double elevation}) {
    _cameraState = _cameraState.copyWith(
      azimuth: azimuth % 360.0,
      elevation: elevation.clamp(-45.0, 45.0),
    );
    notifyListeners();
  }

  void zoom(double factor) {
    final nextDistance = (_cameraState.distance * factor).clamp(0.5, 3.0);
    _cameraState = _cameraState.copyWith(distance: nextDistance);
    notifyListeners();
  }

  void resetCamera() {
    _cameraState = const PetCameraState();
    _pose = PetPose.identity;
    notifyListeners();
  }

  void lookAt({required double x, required double y}) {
    final clampedX = x.clamp(-1.0, 1.0);
    final clampedY = y.clamp(-1.0, 1.0);

    _pose = _pose.copyWith(
      yaw: clampedX * 0.48, // ~28 degrees
      pitch: -clampedY * 0.38, // ~22 degrees
      roll: clampedX * 0.10,
    );
    notifyListeners();
  }

  void playAnimation(PetAnimation animation) {
    _currentAnimation = animation;
    notifyListeners();
  }

  void setExpression(PetExpression expression) {
    _currentExpression = expression;
    notifyListeners();
  }
}
