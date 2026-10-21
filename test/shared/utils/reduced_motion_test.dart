import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/shared/utils/reduced_motion.dart';

void main() {
  testWidgets('decorative loops run normally by default', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    );

    controller.repeatUnlessReducedMotion();
    expect(controller.status, AnimationStatus.forward);
    controller.dispose();
  });

  testWidgets('decorative loops park when reduce motion is on', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    );

    controller.repeatUnlessReducedMotion(staticValue: 0.25);
    expect(prefersReducedMotion, isTrue);
    expect(controller.isAnimating, isFalse);
    expect(controller.value, 0.25);
    controller.dispose();
  });
}
