import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

/// True when the OS asks for reduced motion or disabled animations.
bool get prefersReducedMotion {
  final features =
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
  return features.disableAnimations || features.reduceMotion;
}

/// Looping animations freeze at a static value when reduced motion is on.
extension ReducedMotionAnimation on AnimationController {
  TickerFuture repeatUnlessReducedMotion({
    bool reverse = false,
    double staticValue = 0.5,
  }) {
    if (prefersReducedMotion) {
      stop();
      value = staticValue;
      return TickerFuture.complete();
    }
    return repeat(reverse: reverse);
  }
}
