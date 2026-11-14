import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart'
    show WidgetsBinding, BuildContext, MediaQuery;

class AppMotion {
  static bool reduceMotion = false;
}

Duration motionDuration(BuildContext context, Duration duration) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? prefersReducedMotion)
    ? Duration.zero
    : duration;

/// True when the OS asks for reduced motion or disabled animations.
bool get prefersReducedMotion {
  final features =
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
  return AppMotion.reduceMotion ||
      features.disableAnimations ||
      features.reduceMotion;
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
