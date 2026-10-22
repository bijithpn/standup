import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/behavior/pet_behavior_engine.dart';
import 'package:breakmate/features/companion/behavior/pet_wanderer.dart';

/// A window that lives entirely in memory.
class _FakeTarget implements WanderTarget {
  _FakeTarget({
    this.size = const Size(280, 320),
    Offset start = const Offset(600, 400),
    List<Rect>? screens,
  }) : position = start,
       _screens = screens ?? <Rect>[const Rect.fromLTWH(0, 0, 1920, 1080)];

  @override
  final Size size;

  @override
  Offset position;

  final List<Rect> _screens;

  final List<Offset> moves = <Offset>[];
  int persists = 0;
  int displayLookups = 0;

  @override
  Future<Offset> readPosition() async => position;

  @override
  Future<void> moveTo(Offset next) async {
    position = next;
    moves.add(next);
  }

  @override
  void persist() => persists++;

  @override
  Future<List<Rect>> displays() async {
    displayLookups++;
    return _screens;
  }
}

/// Drives a wanderer through a whole journey without waiting in real time.
Future<void> walk(PetWanderer wanderer, {int steps = 200}) async {
  for (var i = 0; i < steps && wanderer.isTravelling; i++) {
    wanderer.tick();
    // Let the queued moveTo futures settle, so the next tick is allowed to
    // issue one rather than skipping while a call is in flight.
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late PetBehaviorEngine engine;

  setUp(() {
    // startLocal, not start: it drives from its own pointer events rather
    // than the shared cursor feed, which needs a platform behind it.
    engine = PetBehaviorEngine(random: math.Random(7))..startLocal();
  });
  tearDown(() => engine.dispose());

  group('deciding whether to move', () {
    test('an idle pet is willing', () {
      final wanderer = PetWanderer(target: _FakeTarget(), engine: engine);
      addTearDown(wanderer.dispose);

      expect(wanderer.wantsToMove, isTrue);
    });

    test('a pet that has just been petted stays where it is', () {
      final wanderer = PetWanderer(target: _FakeTarget(), engine: engine);
      addTearDown(wanderer.dispose);

      engine.pet();
      engine.tick(const Duration(milliseconds: 16));
      engine.tick(const Duration(milliseconds: 32));

      expect(wanderer.wantsToMove, isFalse);
    });

    test('a pet mid-game stays where it is', () {
      final wanderer = PetWanderer(target: _FakeTarget(), engine: engine);
      addTearDown(wanderer.dispose);

      engine.play();
      engine.tick(const Duration(milliseconds: 16));
      engine.tick(const Duration(milliseconds: 32));

      expect(wanderer.wantsToMove, isFalse);
    });
  });

  group('choosing where to go', () {
    test('never leaves the display, wherever it starts', () {
      const screen = Rect.fromLTWH(0, 0, 1440, 900);
      const size = Size(280, 320);
      final random = math.Random(7);
      final target = _FakeTarget(size: size, screens: <Rect>[screen]);
      final wanderer = PetWanderer(
        target: target,
        engine: engine,
        random: random,
      );
      addTearDown(wanderer.dispose);

      // Corners included, because that is where clamping either works or
      // silently pushes the window half off the screen.
      final origins = <Offset>[
        const Offset(0, 0),
        const Offset(1160, 580),
        const Offset(700, 300),
        const Offset(18, 560),
      ];

      for (final origin in origins) {
        for (var i = 0; i < 40; i++) {
          final next = wanderer.pickTarget(origin, screen, size);
          expect(next.dx, greaterThanOrEqualTo(screen.left));
          expect(next.dy, greaterThanOrEqualTo(screen.top));
          expect(next.dx + size.width, lessThanOrEqualTo(screen.right));
          expect(next.dy + size.height, lessThanOrEqualTo(screen.bottom));
        }
      }
    });

    test(
      'stays on the second monitor when that is where the window is',
      () async {
        const left = Rect.fromLTWH(0, 0, 1920, 1080);
        const right = Rect.fromLTWH(1920, 0, 1920, 1080);
        final target = _FakeTarget(
          start: const Offset(2400, 500),
          screens: <Rect>[left, right],
        );
        final wanderer = PetWanderer(
          target: target,
          engine: engine,
          random: math.Random(3),
        );
        addTearDown(wanderer.dispose);

        await wanderer.beginJourney();

        expect(wanderer.destination, isNotNull);
        expect(right.contains(wanderer.destination!), isTrue);
      },
    );

    test('drifts toward the edge it is already nearest', () {
      const screen = Rect.fromLTWH(0, 0, 1600, 900);
      const size = Size(280, 320);
      final wanderer = PetWanderer(
        target: _FakeTarget(size: size, screens: <Rect>[screen]),
        engine: engine,
        random: math.Random(11),
      );
      addTearDown(wanderer.dispose);

      // Well left of centre: over many rolls the average destination should be
      // further left still, not drawn back to the middle.
      const origin = Offset(300, 400);
      var total = 0.0;
      const rolls = 200;
      for (var i = 0; i < rolls; i++) {
        total += wanderer.pickTarget(origin, screen, size).dx;
      }

      expect(total / rolls, lessThan(origin.dx));
    });
  });

  group('walking', () {
    test('arrives at the spot it chose, and persists once', () async {
      final target = _FakeTarget();
      final wanderer = PetWanderer(
        target: target,
        engine: engine,
        random: math.Random(5),
      );
      addTearDown(wanderer.dispose);

      await wanderer.beginJourney();
      final destination = wanderer.destination;
      expect(destination, isNotNull);

      await walk(wanderer);

      expect(wanderer.isTravelling, isFalse);
      expect(target.position.dx, closeTo(destination!.dx, 0.5));
      expect(target.position.dy, closeTo(destination.dy, 0.5));
      expect(target.persists, 1);
      // It genuinely animated rather than teleporting.
      expect(target.moves.length, greaterThan(5));
    });

    test(
      'tells the pet which way it is going, and that it has stopped',
      () async {
        final target = _FakeTarget();
        final wanderer = PetWanderer(
          target: target,
          engine: engine,
          random: math.Random(5),
        );
        addTearDown(wanderer.dispose);

        await wanderer.beginJourney();

        // Part way through, the body should be leaning into the travel.
        for (var i = 0; i < 12; i++) {
          wanderer.tick();
          await Future<void>.delayed(Duration.zero);
        }
        // A tick shorter than one simulation step publishes nothing, so time
        // has to be handed over in slices the engine will actually run.
        engine.tick(const Duration(milliseconds: 100));
        final travelling = engine.snapshot.bodyLean;

        await walk(wanderer);
        engine.tick(const Duration(milliseconds: 200));

        expect(travelling.distance, greaterThan(0.0));
        // Lean unwinds through a spring, so the check is that the travel
        // contribution is gone rather than that the body is exactly at rest.
        expect(
          engine.snapshot.bodyLean.distance,
          lessThan(travelling.distance),
        );
      },
    );

    test('suspending mid-walk stops it where it stands', () async {
      final target = _FakeTarget();
      final wanderer = PetWanderer(
        target: target,
        engine: engine,
        random: math.Random(5),
      );
      addTearDown(wanderer.dispose);

      await wanderer.beginJourney();
      final destination = wanderer.destination!;

      for (var i = 0; i < 6; i++) {
        wanderer.tick();
        await Future<void>.delayed(Duration.zero);
      }
      wanderer.suspend();

      final stoppedAt = target.position;
      await walk(wanderer, steps: 50);

      expect(wanderer.isTravelling, isFalse);
      expect(target.position, stoppedAt);
      expect((stoppedAt - destination).distance, greaterThan(1));
    });

    test('a suspended wanderer starts nothing new', () async {
      final target = _FakeTarget();
      final wanderer = PetWanderer(
        target: target,
        engine: engine,
        random: math.Random(5),
      );
      addTearDown(wanderer.dispose);

      wanderer.suspend();
      await wanderer.beginJourney();

      expect(wanderer.isTravelling, isFalse);
      expect(target.moves, isEmpty);
    });

    test('turning wandering off abandons the walk in progress', () async {
      final target = _FakeTarget();
      final wanderer = PetWanderer(
        target: target,
        engine: engine,
        random: math.Random(5),
      );
      addTearDown(wanderer.dispose);

      await wanderer.beginJourney();
      expect(wanderer.isTravelling, isTrue);

      wanderer.enabled = false;

      expect(wanderer.isTravelling, isFalse);
      expect(engine.snapshot.bodyLean.distance, lessThan(0.001));
    });

    test('reports arrival so the owner can resync', () async {
      var arrivals = 0;
      final wanderer = PetWanderer(
        target: _FakeTarget(),
        engine: engine,
        random: math.Random(5),
        onArrived: () => arrivals++,
      );
      addTearDown(wanderer.dispose);

      await wanderer.beginJourney();
      await walk(wanderer);

      expect(arrivals, 1);
    });
  });

  group('cost', () {
    test('does not ask the platform for displays on every tick', () async {
      final target = _FakeTarget();
      final wanderer = PetWanderer(
        target: target,
        engine: engine,
        random: math.Random(5),
      );
      addTearDown(wanderer.dispose);

      await wanderer.beginJourney();
      await walk(wanderer);
      await wanderer.beginJourney();

      // Two journeys inside the cache window is one enumeration: asking the
      // OS to list monitors is not free, and the answer almost never changes.
      expect(target.displayLookups, 1);
    });

    test('never has two window moves in flight at once', () async {
      final target = _FakeTarget();
      final wanderer = PetWanderer(
        target: target,
        engine: engine,
        random: math.Random(5),
      );
      addTearDown(wanderer.dispose);

      await wanderer.beginJourney();

      // Ticking without letting the futures drain must not queue up a move
      // per tick — that backlog is what makes a window stutter after a walk.
      for (var i = 0; i < 10; i++) {
        wanderer.tick();
      }

      expect(target.moves.length, 1);
    });
  });
}
