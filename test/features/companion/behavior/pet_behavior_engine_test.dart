import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/behavior/pet_behavior_snapshot.dart';

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
          engine.pointerMoved(
            _center + Offset(240, i.isEven ? 6 : -6),
          );
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

      _advance(engine, 2.0, each: (_) => engine.pointerMoved(const Offset(10, 10)));

      expect(engine.snapshot.gaze.dx.isFinite, isTrue);
      expect(engine.snapshot.gaze.dy.isFinite, isTrue);
    });
  });
}
