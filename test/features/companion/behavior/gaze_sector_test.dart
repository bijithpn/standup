import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/behavior/gaze_sector.dart';

void main() {
  group('GazeSectorTracker', () {
    test('maps every compass direction to its sector', () {
      final cases = <Offset, GazeDirection>{
        const Offset(200, 0): GazeDirection.right,
        const Offset(200, 200): GazeDirection.downRight,
        const Offset(0, 200): GazeDirection.down,
        const Offset(-200, 200): GazeDirection.downLeft,
        const Offset(-200, 0): GazeDirection.left,
        const Offset(-200, -200): GazeDirection.upLeft,
        const Offset(0, -200): GazeDirection.up,
        const Offset(200, -200): GazeDirection.upRight,
      };
      for (final entry in cases.entries) {
        // A fresh tracker each time, so hysteresis from the previous case
        // cannot colour the answer.
        final tracker = GazeSectorTracker();
        expect(tracker.update(entry.key), entry.value, reason: '${entry.key}');
      }
    });

    test('stays centred inside the dead zone', () {
      final tracker = GazeSectorTracker(deadZone: 60);
      expect(tracker.update(const Offset(30, -20)), GazeDirection.center);
      expect(tracker.update(Offset.zero), GazeDirection.center);
    });

    test('dead zone has radial hysteresis in both directions', () {
      final tracker = GazeSectorTracker(deadZone: 60, deadZoneExit: 1.5);
      // Centred: 70 is outside the dead zone but short of the exit radius (90).
      expect(tracker.update(const Offset(70, 0)), GazeDirection.center);
      expect(tracker.update(const Offset(95, 0)), GazeDirection.right);
      // Off-centre it only returns once back inside the dead zone itself.
      expect(tracker.update(const Offset(70, 0)), GazeDirection.right);
      expect(tracker.update(const Offset(50, 0)), GazeDirection.center);
    });

    test(
      'a pointer resting on the rim does not make the pet look back and forth',
      () {
        final tracker = GazeSectorTracker(deadZone: 100, deadZoneExit: 1.3);
        var changes = 0;
        var last = tracker.direction;
        for (var i = 0; i < 50; i++) {
          final next = tracker.update(Offset(i.isEven ? 98 : 112, 0));
          if (next != last) changes++;
          last = next;
        }
        expect(changes, 0);
      },
    );

    test('does not flicker when the pointer wobbles on a sector boundary', () {
      final tracker = GazeSectorTracker(deadZone: 10);
      // 22.5° is the boundary between right and downRight.
      Offset at(double degrees) =>
          Offset.fromDirection(degrees * 3.141592653589793 / 180, 300);

      expect(tracker.update(at(10)), GazeDirection.right);
      var changes = 0;
      var last = tracker.direction;
      for (var i = 0; i < 40; i++) {
        final angle = 22.5 + (i.isEven ? 3.0 : -3.0);
        final next = tracker.update(at(angle));
        if (next != last) changes++;
        last = next;
      }
      expect(changes, 0, reason: 'wobble inside the hysteresis band');
    });

    test('changes sector once the pointer clearly crosses the boundary', () {
      final tracker = GazeSectorTracker(deadZone: 10);
      Offset at(double degrees) =>
          Offset.fromDirection(degrees * 3.141592653589793 / 180, 300);
      expect(tracker.update(at(10)), GazeDirection.right);
      expect(tracker.update(at(40)), GazeDirection.downRight);
      expect(tracker.update(at(80)), GazeDirection.down);
    });

    test('handles the wrap-around between left and up-left', () {
      final tracker = GazeSectorTracker(deadZone: 10);
      Offset at(double degrees) =>
          Offset.fromDirection(degrees * 3.141592653589793 / 180, 300);
      expect(tracker.update(at(179)), GazeDirection.left);
      expect(tracker.update(at(-179)), GazeDirection.left);
      expect(tracker.update(at(-140)), GazeDirection.upLeft);
    });

    test('reset forgets the sector', () {
      final tracker = GazeSectorTracker(deadZone: 10);
      tracker.update(const Offset(300, 0));
      tracker.reset();
      expect(tracker.direction, GazeDirection.center);
    });
  });

  group('GazeDirection', () {
    test('unit vectors have length one, except centre', () {
      for (final d in GazeDirection.values) {
        if (d == GazeDirection.center) {
          expect(d.unit, Offset.zero);
        } else {
          expect(d.unit.distance, closeTo(1.0, 1e-9));
        }
      }
    });

    test('left faces the viewer\'s left and right faces the right', () {
      expect(GazeDirection.left.unit.dx, lessThan(0));
      expect(GazeDirection.right.unit.dx, greaterThan(0));
      expect(GazeDirection.up.unit.dy, lessThan(0));
      expect(GazeDirection.down.unit.dy, greaterThan(0));
    });
  });

  group('GazeSettings', () {
    test('higher sensitivity shrinks the dead zone and widens interest', () {
      const low = GazeSettings(sensitivity: 0.0);
      const high = GazeSettings(sensitivity: 1.0);
      expect(high.deadZone, lessThan(low.deadZone));
      expect(high.interestRadius, greaterThan(low.interestRadius));
    });

    test('out-of-range sensitivity is clamped', () {
      expect(
        const GazeSettings(sensitivity: 5).deadZone,
        const GazeSettings(sensitivity: 1).deadZone,
      );
      expect(
        const GazeSettings(sensitivity: -2).deadZone,
        const GazeSettings(sensitivity: 0).deadZone,
      );
    });
  });
}
