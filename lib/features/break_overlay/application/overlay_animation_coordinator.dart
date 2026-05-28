import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

class OverlayAnimationCoordinator extends ChangeNotifier {
  AnimationController? _mainController;
  
  void registerController(AnimationController controller) {
    _mainController = controller;
    _mainController?.addListener(notifyListeners);
  }

  void disposeController() {
    _mainController?.removeListener(notifyListeners);
    _mainController = null;
  }

  double get progress => _mainController?.value ?? 0.0;
}
