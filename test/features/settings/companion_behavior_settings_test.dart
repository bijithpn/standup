import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/settings/settings_model.dart';

void main() {
  group('defaults', () {
    test('the companion looks at the pointer, breathes and reacts', () {
      const s = SettingsModel();
      expect(s.companionGazeEnabled, isTrue);
      expect(s.companionGazeSensitivity, 0.5);
      expect(s.companionIdleAnimation, isTrue);
      expect(s.companionReactions, isTrue);
      expect(s.companionReducedMotion, isFalse);
    });
  });

  group('copyWith', () {
    test('changes only the field asked for', () {
      const s = SettingsModel();
      final changed = s.copyWith(companionGazeEnabled: false);
      expect(changed.companionGazeEnabled, isFalse);
      expect(changed.companionGazeSensitivity, 0.5);
      expect(changed.companionIdleAnimation, isTrue);

      final back = changed.copyWith();
      expect(back.companionGazeEnabled, isFalse);
    });
  });

  group('serialisation', () {
    test('round-trips every companion behaviour preference', () {
      final s = const SettingsModel().copyWith(
        companionGazeEnabled: false,
        companionGazeSensitivity: 0.82,
        companionIdleAnimation: false,
        companionReactions: false,
        companionReducedMotion: true,
      );
      final restored = SettingsModel.fromMap(s.toMap());

      expect(restored.companionGazeEnabled, isFalse);
      expect(restored.companionGazeSensitivity, 0.82);
      expect(restored.companionIdleAnimation, isFalse);
      expect(restored.companionReactions, isFalse);
      expect(restored.companionReducedMotion, isTrue);
    });

    test('settings saved before these existed load with the defaults', () {
      final restored = SettingsModel.fromMap(<String, dynamic>{});
      expect(restored.companionGazeEnabled, isTrue);
      expect(restored.companionGazeSensitivity, 0.5);
      expect(restored.companionIdleAnimation, isTrue);
      expect(restored.companionReactions, isTrue);
      expect(restored.companionReducedMotion, isFalse);
    });
  });

  group('overlay payload', () {
    test('carries the behaviour preferences to the companion engine', () {
      const args = PipWindowArgs(
        themeId: 'avatar_cat',
        petName: 'Mochi',
        scale: 6,
        gazeEnabled: false,
        gazeSensitivity: 0.9,
        idleAnimation: false,
        reactionsEnabled: false,
        reducedMotion: true,
        animationsEnabled: false,
      );
      final decoded = PipWindowArgs.fromMap(args.toMap());

      expect(decoded.gazeEnabled, isFalse);
      expect(decoded.gazeSensitivity, 0.9);
      expect(decoded.idleAnimation, isFalse);
      expect(decoded.reactionsEnabled, isFalse);
      expect(decoded.reducedMotion, isTrue);
      expect(decoded.animationsEnabled, isFalse);
    });

    test('omits what was not specified so partial syncs stay partial', () {
      const args = PipWindowArgs(themeId: 'avatar_cat', petName: 'M', scale: 1);
      final map = args.toMap();
      expect(map.containsKey('gazeEnabled'), isFalse);
      expect(map.containsKey('reducedMotion'), isFalse);
    });
  });
}
