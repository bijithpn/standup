import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

/// Whether the OS asks apps to minimise motion (macOS "Reduce motion",
/// Windows "Show animations" off). Readable from `initState`, where
/// `MediaQuery` is not yet available.
bool get prefersReducedMotion {
  final features =
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
  return features.disableAnimations || features.reduceMotion;
}

extension ReducedMotionAnimation on AnimationController {
  /// Like [repeat], but leaves purely decorative loops parked at [staticValue]
  /// when the user has asked for reduced motion.
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
