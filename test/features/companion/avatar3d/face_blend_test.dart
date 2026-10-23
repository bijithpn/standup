import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/avatar3d/avatar_face_expression.dart';
import 'package:breakmate/features/companion/avatar3d/avatar_scene.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';

void main() {
  const face = AvatarFaceStyle(mouthEnabled: true, mouthWidth: 30);

  PetEmotionState full(PetEmotion e) =>
      PetEmotionState(emotion: e, intensity: 1.0);

  group('face blending', () {
    test('ends exactly on either face', () {
      final a = expressFace(face, full(PetEmotion.content));
      final b = expressFace(face, full(PetEmotion.laughing));
      expect(a.lerpTo(b, 0).isCloseTo(a, epsilon: 1e-9), isTrue);
      expect(a.lerpTo(b, 1).isCloseTo(b, epsilon: 1e-9), isTrue);
    });

    test('moves numbers smoothly and monotonically between two faces', () {
      final a = expressFace(face, full(PetEmotion.content));
      final b = expressFace(face, full(PetEmotion.startled));
      var last = a.height;
      for (var i = 1; i <= 10; i++) {
        final h = a.lerpTo(b, i / 10).height;
        expect(h, greaterThanOrEqualTo(last));
        last = h;
      }
    });

    test('a mouth that is going away shrinks instead of vanishing', () {
      final a = expressFace(face, full(PetEmotion.content));
      final b = expressFace(face, full(PetEmotion.sleepy));
      expect(b.mouthEnabled, isFalse);
      final mid = a.lerpTo(b, 0.6);
      expect(mid.mouthEnabled, isTrue);
      expect(mid.mouthWidth, lessThan(a.mouthWidth));
    });

    test('every emotion produces a face with sane proportions', () {
      for (final e in PetEmotion.values) {
        final f = expressFace(face, full(e));
        expect(f.height, greaterThan(0), reason: e.name);
        expect(f.width, greaterThan(0), reason: e.name);
        expect(f.mouthWidth, greaterThan(0), reason: e.name);
        expect(f.mouthHeight, greaterThan(0), reason: e.name);
      }
    });
  });
}
