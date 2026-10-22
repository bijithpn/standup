import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/pet_animation.dart';
import 'package:breakmate/features/companion/engine/pet_procedural_animator.dart';

void main() {
  group('PetProceduralAnimator', () {
    test('computes subtle breathing oscillations without rotating whole body continuously', () {
      final animator = PetProceduralAnimator();
      animator.update(0.016);

      final state = animator.currentState;
      expect(state.scaleX, closeTo(1.0, 0.05));
      expect(state.scaleY, closeTo(1.0, 0.05));
      expect(state.offsetY, inInclusiveRange(-10.0, 10.0));
    });

    test('random blink collapses eye scale momentarily', () {
      final animator = PetProceduralAnimator();
      animator.triggerBlink();

      final state = animator.currentState;
      expect(state.eyeScaleY, equals(0.1));

      // Advance past blink duration (150ms)
      animator.update(0.200);
      expect(animator.currentState.eyeScaleY, equals(1.0));
    });

    test('transitions between animation states', () {
      final animator = PetProceduralAnimator();
      expect(animator.animation, equals(PetAnimation.idle));

      animator.playAnimation(PetAnimation.happy);
      expect(animator.animation, equals(PetAnimation.happy));
      animator.update(0.1);
      expect(animator.currentState.bounceAmount, greaterThan(0.0));
    });
  });
}
