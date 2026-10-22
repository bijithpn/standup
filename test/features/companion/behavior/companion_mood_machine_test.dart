import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/behavior/companion_mood_machine.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';

Duration _t(int ms) => Duration(milliseconds: ms);

void main() {
  group('transitions', () {
    test('starts idle', () {
      expect(CompanionMoodMachine().mood, CompanionMood.idle);
    });

    test('pointer entering makes it curious, then it settles back', () {
      final m = CompanionMoodMachine();
      expect(m.post(CompanionEvent.pointerEntered, _t(0)), isTrue);
      expect(m.mood, CompanionMood.curious);

      m.post(CompanionEvent.pointerExited, _t(100));
      expect(m.advance(_t(100 + 2300)), isTrue);
      expect(m.mood, CompanionMood.idle);
    });

    test('curiosity lingers while the pointer is still near', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.pointerEntered, _t(0));
      m.advance(_t(5000));
      expect(m.mood, CompanionMood.curious);
      m.post(CompanionEvent.pointerExited, _t(5000));
      m.advance(_t(8000));
      expect(m.mood, CompanionMood.idle);
    });

    test('click makes it attentive for a moment', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.clicked, _t(0));
      expect(m.mood, CompanionMood.attentive);
      m.advance(_t(1500));
      expect(m.mood, CompanionMood.idle);
    });

    test('completed break makes it happy', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.breakCompleted, _t(0));
      expect(m.mood, CompanionMood.happy);
      m.advance(_t(4000));
      expect(m.mood, CompanionMood.idle);
    });

    test('break reminder is encouraging', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.breakReminder, _t(0));
      expect(m.mood, CompanionMood.encouraging);
    });

    test('sudden motion is a brief surprise', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.suddenMotion, _t(0));
      expect(m.mood, CompanionMood.surprised);
      m.advance(_t(1000));
      expect(m.mood, CompanionMood.idle);
    });

    test('quiet period sleeps and activity wakes', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.quietPeriodStarted, _t(0));
      expect(m.mood, CompanionMood.sleepy);
      m.post(CompanionEvent.quietPeriodEnded, _t(10));
      expect(m.mood, CompanionMood.idle);
    });

    test('a click wakes a sleepy companion', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.quietPeriodStarted, _t(0));
      m.post(CompanionEvent.clicked, _t(10));
      expect(m.mood, CompanionMood.attentive);
      m.advance(_t(5000));
      expect(m.mood, CompanionMood.idle, reason: 'no longer quiet');
    });
  });

  group('priority', () {
    test('a lower-priority event never replaces a higher one', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.breakCompleted, _t(0));
      expect(m.post(CompanionEvent.pointerEntered, _t(100)), isFalse);
      expect(m.post(CompanionEvent.clicked, _t(200)), isFalse);
      expect(m.mood, CompanionMood.happy);
    });

    test('a higher-priority event takes over', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.pointerEntered, _t(0));
      m.post(CompanionEvent.clicked, _t(100));
      expect(m.mood, CompanionMood.attentive);
      m.post(CompanionEvent.suddenMotion, _t(200));
      expect(m.mood, CompanionMood.surprised);
    });

    test('idle updates cannot overwrite a showing reaction', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.breakCompleted, _t(0));
      m.post(CompanionEvent.quietPeriodEnded, _t(100));
      expect(m.advance(_t(200)), isFalse);
      expect(m.mood, CompanionMood.happy);
    });

    test('a reaction on a sleepy pet returns to sleepy, not idle', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.quietPeriodStarted, _t(0));
      m.post(CompanionEvent.pointerEntered, _t(100));
      expect(m.mood, CompanionMood.curious);
      m.post(CompanionEvent.pointerExited, _t(200));
      m.advance(_t(5000));
      expect(m.mood, CompanionMood.sleepy);
    });
  });

  group('duplicates', () {
    test('repeating the same reaction does not restart it', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.breakCompleted, _t(0));
      final serial = m.reactionSerial;

      expect(m.post(CompanionEvent.breakCompleted, _t(500)), isFalse);
      expect(m.post(CompanionEvent.breakCompleted, _t(900)), isFalse);
      expect(m.reactionSerial, serial);

      // It still ends on its original schedule rather than being extended.
      m.advance(_t(3700));
      expect(m.mood, CompanionMood.idle);
    });

    test('the serial advances once per real change', () {
      final m = CompanionMoodMachine();
      final start = m.reactionSerial;
      m.post(CompanionEvent.clicked, _t(0));
      m.post(CompanionEvent.clicked, _t(10));
      m.advance(_t(2000));
      expect(m.reactionSerial, start + 2); // idle -> attentive -> idle
    });
  });

  group('configuration', () {
    test('disabling animations rests the companion and ignores events', () {
      final m = CompanionMoodMachine(
        config: const CompanionMoodConfig(animationsEnabled: false),
      );
      expect(m.mood, CompanionMood.resting);
      m.post(CompanionEvent.clicked, _t(0));
      m.post(CompanionEvent.breakCompleted, _t(10));
      m.post(CompanionEvent.suddenMotion, _t(20));
      expect(m.mood, CompanionMood.resting);
    });

    test('turning animations back on leaves resting', () {
      final m = CompanionMoodMachine();
      m.configure(const CompanionMoodConfig(animationsEnabled: false));
      expect(m.mood, CompanionMood.resting);
      m.configure(const CompanionMoodConfig());
      expect(m.mood, CompanionMood.idle);
    });

    test('turning animations off mid-reaction ends it at once', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.breakCompleted, _t(0));
      m.configure(const CompanionMoodConfig(animationsEnabled: false));
      expect(m.mood, CompanionMood.resting);
    });

    test('reactions off silences happy/encouraging/surprised only', () {
      final m = CompanionMoodMachine(
        config: const CompanionMoodConfig(reactionsEnabled: false),
      );
      m.post(CompanionEvent.breakCompleted, _t(0));
      m.post(CompanionEvent.breakReminder, _t(10));
      m.post(CompanionEvent.suddenMotion, _t(20));
      expect(m.mood, CompanionMood.idle);

      m.post(CompanionEvent.clicked, _t(30));
      expect(m.mood, CompanionMood.attentive, reason: 'clicks still answered');
    });

    test('turning reactions off ends a showing celebration', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.breakCompleted, _t(0));
      m.configure(const CompanionMoodConfig(reactionsEnabled: false));
      expect(m.mood, CompanionMood.idle);
    });

    test('interactions off ignores proximity and clicks', () {
      final m = CompanionMoodMachine(
        config: const CompanionMoodConfig(interactionsEnabled: false),
      );
      m.post(CompanionEvent.pointerEntered, _t(0));
      m.post(CompanionEvent.clicked, _t(10));
      expect(m.mood, CompanionMood.idle);
      m.post(CompanionEvent.breakCompleted, _t(20));
      expect(m.mood, CompanionMood.happy);
    });

    test('the quiet period survives a configuration change', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.quietPeriodStarted, _t(0));
      m.configure(const CompanionMoodConfig(reactionsEnabled: false));
      expect(m.mood, CompanionMood.sleepy);
    });
  });

  group('reconcile', () {
    test('drops stale reactions after the host was suspended', () {
      final m = CompanionMoodMachine();
      m.post(CompanionEvent.pointerEntered, _t(0));
      m.reconcile(_t(600000));
      expect(m.mood, CompanionMood.idle);
      // And no timer is left pending from before.
      expect(m.advance(_t(700000)), isFalse);
    });
  });

  group('presentation', () {
    test('every mood maps to a face with a sensible intensity', () {
      for (final mood in CompanionMood.values) {
        expect(mood.intensity, inInclusiveRange(0.0, 1.0));
        expect(PetEmotion.values, contains(mood.emotion));
      }
    });

    test('timed moods have durations, standing moods do not', () {
      expect(CompanionMood.happy.duration, isNotNull);
      expect(CompanionMood.sleepy.duration, isNull);
      expect(CompanionMood.resting.duration, isNull);
    });
  });
}
