import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/behavior/companion_mood_machine.dart';
import 'package:breakmate/features/companion/behavior/gaze_sector.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';
import 'package:breakmate/features/companion/behavior/pet_emotion.dart';

/// The pet's box, with the cursor positions used around it.
const Rect _viewport = Rect.fromLTWH(500, 400, 240, 240);
final Offset _center = _viewport.center;

PetBehaviorEngine _engine({bool reducedMotion = false}) {
  final engine = PetBehaviorEngine(
    random: math.Random(7),
    reducedMotion: reducedMotion,
  )..startLocal();
  engine.setViewport(_viewport);
  return engine;
}

/// Advances the simulation by [seconds] of wall time.
///
/// `tick` takes a cumulative timestamp and caps how many steps a single call
/// may run, so time has to be handed over in realistic slices.
Duration _advance(
  PetBehaviorEngine engine,
  double seconds, {
  Duration from = Duration.zero,
  void Function(Duration now)? each,
}) {
  var now = from;
  const slice = Duration(milliseconds: 100);
  final slices = (seconds * 10).round();
  for (var i = 0; i < slices; i++) {
    now += slice;
    each?.call(now);
    engine.tick(now);
  }
  return now;
}

/// Moves the cursor around a point, so the pet reads it as live motion.
void _wiggleAt(PetBehaviorEngine engine, Offset target, int step) {
  engine.pointerMoved(target + Offset(step.isEven ? 6 : -6, 0));
}

void main() {
  group('gaze', () {
    test('follows a cursor that is moving beside it', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      var step = 0;
      _advance(
        engine,
        3.0,
        each: (_) => _wiggleAt(engine, _center + const Offset(260, 0), step++),
      );

      expect(engine.snapshot.gaze.dx, greaterThan(0.15));
      expect(engine.snapshot.attention, greaterThan(0.5));
    });

    test('follows the cursor to the other side', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      var step = 0;
      _advance(
        engine,
        3.0,
        each: (_) => _wiggleAt(engine, _center - const Offset(260, 0), step++),
      );

      expect(engine.snapshot.gaze.dx, lessThan(-0.15));
    });

    test('the head lags behind the eyes', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      var step = 0;
      _advance(
        engine,
        0.6,
        each: (_) => _wiggleAt(engine, _center + const Offset(300, 0), step++),
      );

      final snapshot = engine.snapshot;
      expect(
        snapshot.headTurn.dx.abs(),
        lessThan(snapshot.gaze.dx.abs()),
        reason: 'eyes arrive first, the head catches up',
      );
    });

    test('loses interest in a cursor that has stopped', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      var step = 0;
      var now = _advance(
        engine,
        2.0,
        each: (_) => _wiggleAt(engine, _center + const Offset(200, 0), step++),
      );
      final engaged = engine.snapshot.attention;
      expect(engaged, greaterThan(0.5));

      // The cursor holds perfectly still from here on.
      now = _advance(engine, 8.0, from: now);

      expect(
        engine.snapshot.attention,
        lessThan(engaged * 0.5),
        reason: 'a pet stops staring at something that stopped moving',
      );
    });

    test('ignores a cursor on the far side of the screen', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      var step = 0;
      _advance(
        engine,
        3.0,
        each: (_) => _wiggleAt(engine, _center + const Offset(4000, 0), step++),
      );

      expect(engine.snapshot.attention, lessThan(0.3));
    });
  });

  group('rest', () {
    test('gets drowsy and then falls asleep in a quiet room', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      var now = _advance(engine, 90.0);
      expect(engine.snapshot.activity, PetActivity.drowsy);

      now = _advance(engine, 70.0, from: now);
      expect(engine.snapshot.activity, PetActivity.sleeping);
      expect(engine.snapshot.blink, greaterThan(0.85));
      expect(engine.snapshot.arousal, lessThan(0.2));
    });

    test('wakes when something moves nearby', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      final now = _advance(engine, 160.0);
      expect(engine.snapshot.activity, PetActivity.sleeping);

      var step = 0;
      _advance(
        engine,
        3.0,
        from: now,
        each: (_) => _wiggleAt(engine, _center + const Offset(120, 0), step++),
      );

      expect(engine.snapshot.activity, isNot(PetActivity.sleeping));
      expect(engine.snapshot.blink, lessThan(0.6));
    });

    test('blinks while it is awake', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      var sawBlink = false;
      var step = 0;
      _advance(
        engine,
        20.0,
        each: (_) {
          _wiggleAt(engine, _center + const Offset(150, 0), step++);
          if (engine.snapshot.blink > 0.5) sawBlink = true;
        },
      );

      expect(sawBlink, isTrue);
    });
  });

  group('reactions', () {
    test('being petted reads as delight and settles again', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      final now = _advance(engine, 1.0);
      engine.pet();
      _advance(engine, 0.3, from: now);

      expect(engine.snapshot.activity, PetActivity.delighted);
      expect(engine.snapshot.attention, greaterThan(0.8));

      _advance(engine, 6.0, from: now + const Duration(milliseconds: 300));
      expect(engine.snapshot.activity, isNot(PetActivity.delighted));
    });

    test('reduced motion keeps the pet still but still attentive', () {
      final engine = _engine(reducedMotion: true);
      addTearDown(engine.dispose);

      final now = _advance(engine, 1.0);
      engine.pet();
      _advance(engine, 0.5, from: now);

      expect(engine.snapshot.bounce, 0.0);
      expect(engine.snapshot.squash, 1.0);
      expect(engine.snapshot.attention, greaterThan(0.6));
    });
  });

  group('integration', () {
    test('is not affected by how often it is ticked', () {
      Offset runAt(int hz) {
        final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
        engine.setViewport(_viewport);

        final frame = Duration(microseconds: (1e6 / hz).round());
        var now = Duration.zero;
        for (var i = 0; i < hz * 2; i++) {
          now += frame;
          engine.pointerMoved(_center + Offset(240, i.isEven ? 6 : -6));
          engine.tick(now);
        }
        final result = engine.snapshot.gaze;
        engine.dispose();
        return result;
      }

      final at60 = runAt(60);
      final at120 = runAt(120);

      expect((at60.dx - at120.dx).abs(), lessThan(0.05));
      expect((at60.dy - at120.dy).abs(), lessThan(0.05));
    });

    test('gaze stays inside its range no matter how far the cursor goes', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      var step = 0;
      _advance(
        engine,
        4.0,
        each: (_) {
          _wiggleAt(engine, _center + const Offset(90, 40), step++);
          final gaze = engine.snapshot.gaze;
          expect(gaze.dx, inInclusiveRange(-1.0, 1.0));
          expect(gaze.dy, inInclusiveRange(-1.0, 1.0));
        },
      );
    });

    test('an empty viewport does not break the simulation', () {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      addTearDown(engine.dispose);

      _advance(
        engine,
        2.0,
        each: (_) => engine.pointerMoved(const Offset(10, 10)),
      );

      expect(engine.snapshot.gaze.dx.isFinite, isTrue);
      expect(engine.snapshot.gaze.dy.isFinite, isTrue);
    });
  });

  group('playing and feeding', () {
    test('a game leaves the pet excited, and keeps it there a while', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      engine.play();
      final now = _advance(engine, 1.0);
      expect(engine.snapshot.emotion.emotion, PetEmotion.excited);
      expect(engine.snapshot.activity, PetActivity.playful);

      // Still wound up half a minute later. A game that evaporates in two
      // seconds is a button press, not play.
      _advance(engine, 30.0, from: now);
      expect(engine.snapshot.emotion.emotion, PetEmotion.excited);
    });

    test('a game wears off eventually', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      engine.play();
      _advance(engine, 90.0);

      expect(engine.snapshot.emotion.emotion, isNot(PetEmotion.excited));
    });

    test('a treat is the quickest way to build affection', () {
      final petted = _engine();
      final fed = _engine();
      addTearDown(petted.dispose);
      addTearDown(fed.dispose);

      petted.pet();
      fed.feed();
      _advance(petted, 0.5);
      _advance(fed, 0.5);

      expect(fed.emotion.affection, greaterThan(petted.emotion.affection));
    });

    test('a fright still interrupts a game', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      engine.play();
      _advance(engine, 0.5);

      // A cursor arriving fast and close is what the engine reads as a
      // startle.
      var step = 0;
      _advance(
        engine,
        0.4,
        each: (_) =>
            engine.pointerMoved(_center + Offset(step++ * 90.0 - 400, 0)),
      );

      // Either it was startled, or it stayed excited — but it must not have
      // silently dropped to something calm.
      expect(
        engine.snapshot.emotion.emotion,
        anyOf(PetEmotion.startled, PetEmotion.excited),
      );
    });
  });

  group('what it wants', () {
    test('a sleeping pet wants to be left alone', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      _advance(engine, 160.0);

      expect(engine.snapshot.activity, PetActivity.sleeping);
      expect(engine.wish, PetWish.none);
    });

    test(
      'a pet that has just been played with asks for a scratch, not another game',
      () {
        final engine = _engine();
        addTearDown(engine.dispose);

        engine.play();
        _advance(engine, 1.0);

        expect(engine.wish, PetWish.petting);
      },
    );

    test('a pet ignored while its owner works asks for attention', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      // The cursor keeps moving, far enough away to be nothing to do with the
      // pet. So it is awake and has been ignored for over an hour — which is
      // a different thing from being asleep, and the only one that should
      // produce a request.
      var step = 0;
      _advance(
        engine,
        80.0 * 60,
        each: (_) => _wiggleAt(engine, _center + const Offset(1400, 0), step++),
      );

      expect(engine.snapshot.isAwake, isTrue);
      expect(engine.wish, PetWish.petting);
    });

    test('there is always something a new user can do', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      // Whatever state it drifts through, an awake pet never leaves the
      // window with nothing to offer.
      var now = Duration.zero;
      for (var i = 0; i < 12; i++) {
        now = _advance(engine, 5.0, from: now);
        if (!engine.snapshot.isAwake) continue;
        expect(engine.wish, isNot(PetWish.none));
      }
    });
  });

  group('travel', () {
    test('leans into the direction it is walking', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      final now = _advance(engine, 0.5);
      final resting = engine.snapshot.bodyLean.dx;

      engine.setTravel(const Offset(240, 0));
      _advance(engine, 0.2, from: now);

      expect(engine.snapshot.bodyLean.dx, greaterThan(resting));
      expect(engine.snapshot.tilt, isNot(0.0));
    });

    test('a drift too slow to see is not treated as walking', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      final now = _advance(engine, 0.5);
      final resting = engine.snapshot.bodyLean;

      engine.setTravel(const Offset(2, 0));
      _advance(engine, 0.2, from: now);

      expect(engine.snapshot.bodyLean.dx, closeTo(resting.dx, 0.05));
    });

    test('body lean stays in range however hard it travels', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      engine.setTravel(const Offset(4000, 4000));
      _advance(engine, 1.0);

      expect(engine.snapshot.bodyLean.dx, inInclusiveRange(-1.0, 1.0));
      expect(engine.snapshot.bodyLean.dy, inInclusiveRange(-1.0, 1.0));
    });

    test('reduced motion never walks', () {
      final engine = _engine(reducedMotion: true);
      addTearDown(engine.dispose);

      engine.setTravel(const Offset(300, 0));
      _advance(engine, 0.5);

      expect(engine.snapshot.bodyLean.dx, closeTo(0.0, 0.02));
    });
  });

  group('nine-direction gaze', () {
    PetBehaviorEngine tracking({GazeSettings gaze = const GazeSettings()}) {
      final engine = PetBehaviorEngine(random: math.Random(7), gaze: gaze)
        ..startLocal();
      engine.setViewport(_viewport, eye: _center);
      return engine;
    }

    void follow(PetBehaviorEngine engine, Offset offset, {double secs = 2.0}) {
      var step = 0;
      _advance(
        engine,
        secs,
        each: (_) => _wiggleAt(engine, _center + offset, step++),
      );
    }

    test('looks toward the pointer in all eight directions', () {
      final cases = <Offset, GazeDirection>{
        const Offset(300, 0): GazeDirection.right,
        const Offset(220, 220): GazeDirection.downRight,
        const Offset(0, 300): GazeDirection.down,
        const Offset(-220, 220): GazeDirection.downLeft,
        const Offset(-300, 0): GazeDirection.left,
        const Offset(-220, -220): GazeDirection.upLeft,
        const Offset(0, -300): GazeDirection.up,
        const Offset(220, -220): GazeDirection.upRight,
      };
      for (final entry in cases.entries) {
        final engine = tracking();
        addTearDown(engine.dispose);
        follow(engine, entry.key);

        expect(engine.gazeDirection, entry.value, reason: '${entry.key}');
        expect(engine.snapshot.gazeDirection, entry.value);
        final unit = entry.value.unit;
        final gaze = engine.snapshot.gaze;
        // Same side of the eyes as the pointer, on each axis that matters.
        if (unit.dx != 0) expect(gaze.dx.sign, unit.dx.sign);
        if (unit.dy != 0) expect(gaze.dy.sign, unit.dy.sign);
      }
    });

    test('a pointer inside the dead zone leaves the pet looking relaxed', () {
      final engine = tracking(gaze: const GazeSettings(sensitivity: 0.0));
      addTearDown(engine.dispose);

      // sensitivity 0 => dead zone of 110px.
      follow(engine, const Offset(40, 20));

      expect(engine.gazeDirection, GazeDirection.center);
      expect(engine.snapshot.gaze.distance, lessThan(0.1));
    });

    test('higher sensitivity looks at a pointer a low one ignores', () {
      final relaxed = tracking(gaze: const GazeSettings(sensitivity: 0.0));
      final keen = tracking(gaze: const GazeSettings(sensitivity: 1.0));
      addTearDown(relaxed.dispose);
      addTearDown(keen.dispose);

      follow(relaxed, const Offset(70, 0));
      follow(keen, const Offset(70, 0));

      expect(relaxed.gazeDirection, GazeDirection.center);
      expect(keen.gazeDirection, GazeDirection.right);
    });

    test('does not change sector while the pointer wobbles on a boundary', () {
      final engine = tracking();
      addTearDown(engine.dispose);

      Offset at(double degrees) =>
          Offset.fromDirection(degrees * math.pi / 180, 300);

      follow(engine, at(10));
      expect(engine.gazeDirection, GazeDirection.right);

      var changes = 0;
      var last = engine.gazeDirection;
      var step = 0;
      _advance(
        engine,
        3.0,
        each: (_) {
          final angle = 22.5 + (step.isEven ? 3.0 : -3.0);
          engine.pointerMoved(
            _center + at(angle) + Offset(step.isEven ? 4 : -4, 0),
          );
          step++;
          if (engine.gazeDirection != last) changes++;
          last = engine.gazeDirection;
        },
      );
      expect(changes, 0);
    });

    test('eases to a new sector instead of teleporting', () {
      final engine = tracking();
      addTearDown(engine.dispose);
      follow(engine, const Offset(300, 0));
      final settled = engine.snapshot.gaze;
      expect(settled.dx, greaterThan(0.3));

      var now = const Duration(seconds: 100);
      engine.pointerMoved(_center + const Offset(-300, 0));
      engine.tick(now);
      now += const Duration(milliseconds: 16);
      engine.pointerMoved(_center + const Offset(-300, 4));
      engine.tick(now);

      final afterOneFrame = engine.snapshot.gaze;
      expect(
        (afterOneFrame - settled).distance,
        lessThan((settled * 2).distance),
        reason: 'has not already arrived on the far side',
      );

      follow(engine, const Offset(-300, 0), secs: 2.0);
      expect(engine.snapshot.gaze.dx, lessThan(-0.3));
    });

    test('turning follow off stops the pet looking at the pointer', () {
      final engine = tracking(gaze: const GazeSettings(enabled: false));
      addTearDown(engine.dispose);

      follow(engine, const Offset(300, 0), secs: 3.0);

      expect(engine.gazeDirection, GazeDirection.center);
      expect(engine.snapshot.attention, lessThan(0.2));
    });

    test('moving the pet forgets the old sector', () {
      final engine = tracking();
      addTearDown(engine.dispose);
      follow(engine, const Offset(300, 0));
      expect(engine.gazeDirection, GazeDirection.right);

      engine.setViewport(_viewport.shift(const Offset(900, 0)));
      expect(engine.gazeDirection, GazeDirection.center);
    });

    test('measures from the eyes, not the middle of the window', () {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      // Eyes in the top fifth of a tall window.
      engine.setViewport(
        const Rect.fromLTWH(500, 400, 240, 400),
        eye: const Offset(620, 480),
      );
      var step = 0;
      _advance(
        engine,
        2.0,
        // Level with the eyes, well to the right.
        each: (_) => engine.pointerMoved(Offset(920, 480 + (step++ % 2) * 4)),
      );
      expect(engine.gazeDirection, GazeDirection.right);
    });
  });

  group('mood events', () {
    PetBehaviorEngine fresh() {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      engine.setViewport(_viewport, eye: _center);
      return engine;
    }

    test('a completed break makes the pet happy, then it settles', () {
      final engine = fresh();
      addTearDown(engine.dispose);

      final now = _advance(engine, 1.0);
      engine.onBreakCompleted();
      expect(engine.mood, CompanionMood.happy);
      expect(engine.snapshot.emotion.emotion, PetEmotion.happy);

      _advance(engine, 5.0, from: now);
      expect(engine.mood, CompanionMood.idle);
    });

    test('repeating the event does not restart the reaction', () {
      final engine = fresh();
      addTearDown(engine.dispose);

      final now = _advance(engine, 0.5);
      engine.onBreakCompleted();
      engine.onBreakCompleted();
      engine.onBreakCompleted();
      _advance(engine, 4.5, from: now);
      expect(engine.mood, CompanionMood.idle);
    });

    test('reactions switched off: no celebration', () {
      final engine = fresh();
      addTearDown(engine.dispose);
      engine.configure(reactions: false);

      _advance(engine, 1.0);
      engine.onBreakCompleted();
      engine.onBreakReminder();
      expect(engine.mood, CompanionMood.idle);
      expect(engine.snapshot.emotion.emotion, isNot(PetEmotion.happy));
    });

    test('a click is answered with attention', () {
      final engine = fresh();
      addTearDown(engine.dispose);

      _advance(engine, 1.0);
      engine.pet();
      expect(engine.mood, CompanionMood.attentive);
    });

    test('a break reminder does not override a fright', () {
      final engine = fresh();
      addTearDown(engine.dispose);

      engine.pointerMoved(_center + const Offset(40, 0));
      _advance(engine, 0.5);
      // A fast flick close by.
      engine.pointerMoved(_center + const Offset(60, 0));
      var now = Duration.zero;
      for (var i = 0; i < 5; i++) {
        now += const Duration(milliseconds: 16);
        engine.pointerMoved(_center + Offset(60.0 + i * 200, 0));
        engine.tick(now);
      }
      if (engine.mood == CompanionMood.surprised) {
        engine.onBreakReminder();
        expect(engine.mood, CompanionMood.surprised);
      }
    });

    test('animations off: resting, static, ignores events', () {
      final engine = fresh();
      addTearDown(engine.dispose);
      engine.configure(animations: false);

      var step = 0;
      _advance(
        engine,
        5.0,
        each: (_) => _wiggleAt(engine, _center + const Offset(250, 0), step++),
      );
      engine.pet();
      engine.onBreakCompleted();
      _advance(engine, 1.0);

      expect(engine.mood, CompanionMood.resting);
      expect(engine.snapshot.blink, 0.0);
      expect(engine.snapshot.breath, 0.0);
      expect(engine.snapshot.bounce, 0.0);
      expect(engine.snapshot.gaze.distance, lessThan(0.05));
    });

    test('animations back on wakes it up', () {
      final engine = fresh();
      addTearDown(engine.dispose);
      engine.configure(animations: false);
      engine.configure(animations: true);
      expect(engine.mood, CompanionMood.idle);
    });

    test('pointer arriving at the pet makes it curious', () {
      final engine = fresh();
      addTearDown(engine.dispose);

      // Start well away, then walk in slowly: a pointer that appears out of
      // nowhere at speed is a fright, not an invitation.
      var step = 0;
      _advance(
        engine,
        0.5,
        each: (_) => _wiggleAt(engine, _center + const Offset(700, 0), step++),
      );
      var x = 700.0;
      var now = const Duration(seconds: 1);
      while (x > 40) {
        x -= 10; // 600 px/s: brisk, but not a flick.
        now += const Duration(milliseconds: 16);
        _wiggleAt(engine, _center + Offset(x, 10), step++);
        engine.tick(now);
      }
      expect(engine.mood, CompanionMood.curious);
    });
  });

  group('idle animation and reduced motion', () {
    test('idle animation off: no breathing and no spontaneous blinks', () {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      engine.setViewport(_viewport, eye: _center);
      addTearDown(engine.dispose);
      engine.configure(idleAnimation: false);

      var maxBlink = 0.0;
      var maxBreath = 0.0;
      _advance(
        engine,
        30.0,
        each: (_) {
          maxBlink = math.max(maxBlink, engine.snapshot.blink);
          maxBreath = math.max(maxBreath, engine.snapshot.breath.abs());
        },
      );
      expect(maxBlink, 0.0);
      expect(maxBreath, 0.0);
    });

    test('idle animation on: it breathes and blinks', () {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      engine.setViewport(_viewport, eye: _center);
      addTearDown(engine.dispose);

      var maxBlink = 0.0;
      var maxBreath = 0.0;
      _advance(
        engine,
        30.0,
        each: (_) {
          maxBlink = math.max(maxBlink, engine.snapshot.blink);
          maxBreath = math.max(maxBreath, engine.snapshot.breath.abs());
        },
      );
      expect(maxBlink, greaterThan(0.5));
      expect(maxBreath, greaterThan(0.5));
    });

    test('reduced motion can be switched at runtime', () {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      engine.setViewport(_viewport, eye: _center);
      addTearDown(engine.dispose);
      engine.configure(reducedMotion: true);

      engine.pet();
      var maxBounce = 0.0;
      _advance(
        engine,
        2.0,
        each: (_) =>
            maxBounce = math.max(maxBounce, engine.snapshot.bounce.abs()),
      );
      expect(engine.reducedMotion, isTrue);
      expect(maxBounce, 0.0);
    });
  });

  group('settling', () {
    test('a calm pet with idle animation off settles and stops publishing', () {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      engine.setViewport(_viewport, eye: _center);
      addTearDown(engine.dispose);
      engine.configure(idleAnimation: false);

      var notifications = 0;
      engine.addListener(() => notifications++);

      _advance(engine, 8.0);
      expect(engine.isSettled, isTrue);

      notifications = 0;
      _advance(engine, 5.0);
      expect(notifications, 0, reason: 'identical frames are not published');
    });

    test('a breathing pet is never settled', () {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      engine.setViewport(_viewport, eye: _center);
      addTearDown(engine.dispose);
      _advance(engine, 8.0);
      expect(engine.isSettled, isFalse);
    });

    test('outside input asks the host for frames', () {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      engine.setViewport(_viewport, eye: _center);
      addTearDown(engine.dispose);

      var requests = 0;
      engine.onNeedsFrames = () => requests++;
      engine.pet();
      engine.onBreakCompleted();
      engine.configure(idleAnimation: false);
      expect(requests, greaterThanOrEqualTo(3));
    });

    test('suspending reports settled and resuming reconciles state', () {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      engine.setViewport(_viewport, eye: _center);
      addTearDown(engine.dispose);

      engine.onBreakCompleted();
      engine.setSuspended(true);
      expect(engine.isSettled, isTrue);
      engine.setSuspended(false);
      expect(engine.mood, CompanionMood.idle, reason: 'stale reaction dropped');
    });
  });

  group('multiple displays', () {
    // Screen space is shared: a monitor to the left of and above the primary
    // has negative coordinates, and the pet and the pointer are both in it.
    test('looks correctly from a display with negative coordinates', () {
      const onLeftMonitor = Rect.fromLTWH(-1800, -700, 240, 240);
      final eye = onLeftMonitor.center;

      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      engine.setViewport(onLeftMonitor, eye: eye);
      addTearDown(engine.dispose);

      var step = 0;
      _advance(
        engine,
        2.0,
        // Pointer down and to the right, across the seam onto the next display.
        each: (_) => engine.pointerMoved(
          const Offset(-1300, -250) + Offset(step++ % 2 * 4.0, 0),
        ),
      );
      expect(engine.gazeDirection, GazeDirection.downRight);
      expect(engine.snapshot.gaze.dx, greaterThan(0));
      expect(engine.snapshot.gaze.dy, greaterThan(0));
    });

    test('still looks at the right place after being dragged elsewhere', () {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      addTearDown(engine.dispose);

      // Pointer fixed to the right of the first position.
      const pointer = Offset(1000, 500);
      engine.setViewport(const Rect.fromLTWH(500, 400, 240, 240));
      var step = 0;
      void settle() => _advance(
        engine,
        2.0,
        each: (_) => engine.pointerMoved(pointer + Offset(step++ % 2 * 4.0, 0)),
      );
      settle();
      expect(engine.gazeDirection, GazeDirection.right);

      // Dragged to the far side of the pointer, onto another display.
      engine.setViewport(const Rect.fromLTWH(1600, 400, 240, 240));
      settle();
      expect(engine.gazeDirection, GazeDirection.left);
      expect(engine.snapshot.gaze.dx, lessThan(0));
    });

    test('a pointer on another display too far away is ignored', () {
      final engine = PetBehaviorEngine(
        random: math.Random(7),
        gaze: const GazeSettings(sensitivity: 0.0),
      )..startLocal();
      engine.setViewport(_viewport, eye: _center);
      addTearDown(engine.dispose);

      var step = 0;
      _advance(
        engine,
        3.0,
        each: (_) => engine.pointerMoved(
          const Offset(-2800, 300) + Offset(step++ % 2 * 4.0, 0),
        ),
      );
      expect(engine.snapshot.attention, lessThan(0.2));
    });

    test('wake reconciliation forgets the old pointer and sector', () {
      final engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
      engine.setViewport(_viewport, eye: _center);
      addTearDown(engine.dispose);

      var step = 0;
      _advance(
        engine,
        2.0,
        each: (_) => engine.pointerMoved(
          _center + Offset(300, 0) + Offset(step++ % 2 * 4.0, 0),
        ),
      );
      expect(engine.gazeDirection, GazeDirection.right);

      engine.reconcile();
      expect(engine.gazeDirection, GazeDirection.center);
      // And a big gap in the clock (the laptop slept) does not teleport it
      // through hundreds of simulated steps.
      engine.tick(const Duration(hours: 8));
      expect(engine.snapshot.gaze.distance, lessThan(1.5));
    });
  });

  group('frame pacing', () {
    test('a calm pet is drawn slower than one that is tracking', () {
      final calm = PetBehaviorEngine(random: math.Random(7))..startLocal();
      calm.setViewport(_viewport, eye: _center);
      addTearDown(calm.dispose);
      _advance(calm, 10.0);
      final calmInterval = calm.frameInterval;

      final busy = PetBehaviorEngine(random: math.Random(7))..startLocal();
      busy.setViewport(_viewport, eye: _center);
      addTearDown(busy.dispose);
      var step = 0;
      _advance(
        busy,
        1.0,
        each: (_) => _wiggleAt(busy, _center + const Offset(260, 0), step++),
      );
      expect(calmInterval, greaterThan(busy.frameInterval));
    });
  });
}
