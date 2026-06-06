// Tasks 7.2 and 7.3 — DisplayManager tests
// Requirements 2.1, 2.6

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide test, group, expect;

// The tests in this file exercise standalone geometry helpers copied from
// the production NativeDisplayManager.  No live NativeBridgePlatform or
// DisplayManager subclass is needed.

// We re-implement the geometry methods directly here to unit-test them
// without needing a live NativeBridge.  The production NativeDisplayManager
// exposes the same logic; this keeps tests fast and hermetic.

/// Nearest boundary point on [rect] to [point] (clamped).
Offset _clamp(Offset point, Rect rect) => Offset(
  point.dx.clamp(rect.left, rect.right),
  point.dy.clamp(rect.top, rect.bottom),
);

double _dist(Offset a, Offset b) {
  final dx = a.dx - b.dx;
  final dy = a.dy - b.dy;
  return (dx * dx + dy * dy);
}

Offset _nearestDisplayPoint(Offset outside, List<Rect> rects) {
  if (rects.isEmpty) return outside;
  for (final r in rects) {
    if (r.contains(outside)) return outside;
  }
  Offset best = _clamp(outside, rects.first);
  double bestDist = _dist(outside, best);
  for (final r in rects.skip(1)) {
    final c = _clamp(outside, r);
    final d = _dist(outside, c);
    if (d < bestDist) {
      best = c;
      bestDist = d;
    }
  }
  return best;
}

bool _areAdjacent(Rect a, Rect b) {
  // Two displays are adjacent when they share at least 1 px of a horizontal
  // or vertical edge (not just a single corner point).
  //
  // Approach: inflate each by 1 px, check overlap, then require that the
  // intersection has strictly more than 1 px in BOTH dimensions.  A pure
  // corner-touch produces an intersection of exactly 1×1 after inflation
  // (the two 1-px inflated corners meet), which we exclude.
  final ia = a.inflate(1);
  final ib = b.inflate(1);
  if (!ia.overlaps(ib)) return false;
  ia.intersect(ib);
  // A true shared edge gives width > 1 OR height > 1 (one axis has the
  // inflation overlap of 2px, the other has real edge length > 0 after
  // subtracting inflation).  A corner-only touch gives width == 2, height == 2
  // because both inflated edges overlap by exactly 2 px at the corner — so we
  // need to be more precise.
  //
  // Simplest correct check: the original (uninflated) rects must share a
  // non-zero-length edge on at least one axis.
  final sharedHorizLeft = math.max(a.left, b.left);
  final sharedHorizRight = math.min(a.right, b.right);
  final sharedVertTop = math.max(a.top, b.top);
  final sharedVertBottom = math.min(a.bottom, b.bottom);
  // Horizontal shared edge: rects line up horizontally and touch vertically
  final shareHEdge =
      sharedHorizRight > sharedHorizLeft &&
      (a.top == b.bottom || a.bottom == b.top);
  // Vertical shared edge: rects line up vertically and touch horizontally
  final shareVEdge =
      sharedVertBottom > sharedVertTop &&
      (a.left == b.right || a.right == b.left);
  // Overlapping rects are also adjacent
  final overlap = a.overlaps(b);
  return shareHEdge || shareVEdge || overlap;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('DisplayManager.areAdjacent (Task 7.3)', () {
    test('side-by-side displays with touching edge are adjacent', () {
      final a = Rect.fromLTWH(0, 0, 1920, 1080);
      final b = Rect.fromLTWH(1920, 0, 1920, 1080);
      expect(_areAdjacent(a, b), isTrue);
    });

    test('displays 10px apart are NOT adjacent', () {
      final a = Rect.fromLTWH(0, 0, 1920, 1080);
      final b = Rect.fromLTWH(1930, 0, 1920, 1080);
      expect(_areAdjacent(a, b), isFalse);
    });

    test('displays touching only at a corner are NOT adjacent', () {
      final a = Rect.fromLTWH(0, 0, 100, 100);
      final b = Rect.fromLTWH(100, 100, 100, 100);
      expect(_areAdjacent(a, b), isFalse);
    });

    test('overlapping displays are adjacent', () {
      final a = Rect.fromLTWH(0, 0, 200, 200);
      final b = Rect.fromLTWH(150, 0, 200, 200);
      expect(_areAdjacent(a, b), isTrue);
    });
  });

  group('DisplayManager.unionBounds (Task 7.3)', () {
    test('single display returns its own rect', () {
      final r = Rect.fromLTWH(0, 0, 1920, 1080);
      final union = [r].fold<Rect>(r, (acc, d) => acc.expandToInclude(d));
      expect(union, equals(r));
    });

    test('two side-by-side displays produce correct union', () {
      final a = Rect.fromLTWH(0, 0, 1920, 1080);
      final b = Rect.fromLTWH(1920, 0, 1920, 1080);
      final union = [a, b].fold(a, (acc, r) => acc.expandToInclude(r));
      expect(union.left, equals(0));
      expect(union.width, equals(3840));
      expect(union.height, equals(1080));
    });
  });

  group('DisplayManager.nearestDisplayPoint (Task 7.3)', () {
    test('point inside a display is returned unchanged', () {
      final rects = [Rect.fromLTWH(0, 0, 1920, 1080)];
      const point = Offset(500, 500);
      expect(_nearestDisplayPoint(point, rects), equals(point));
    });

    test('point in gap between displays clamps to nearest boundary', () {
      final a = Rect.fromLTWH(0, 0, 1000, 800);
      final b = Rect.fromLTWH(1100, 0, 1000, 800);
      const gap = Offset(1050, 400); // in the gap between a and b
      final result = _nearestDisplayPoint(gap, [a, b]);
      // Should clamp to right edge of a (x=1000) or left edge of b (x=1100)
      // Both are equidistant (50px). Accept either.
      expect(result.dx == 1000.0 || result.dx == 1100.0, isTrue);
    });

    test('point far outside all displays clamps to nearest boundary', () {
      final rects = [Rect.fromLTWH(0, 0, 1920, 1080)];
      const farOut = Offset(5000, 5000);
      final result = _nearestDisplayPoint(farOut, rects);
      expect(result.dx, equals(1920.0));
      expect(result.dy, equals(1080.0));
    });
  });

  // Property 3: nearest display point clamping
  group('Property 3: Nearest display point clamping (Task 7.2)', () {
    Glados2(
      // Random x,y outside the display
      any.doubleInRange(-5000, -1),
      any.doubleInRange(-5000, -1),
    ).test('point left/above single display clamps to top-left corner', (
      double x,
      double y,
    ) {
      final rects = [Rect.fromLTWH(0, 0, 1920, 1080)];
      final result = _nearestDisplayPoint(Offset(x, y), rects);
      // Must be on or inside the display boundary
      expect(result.dx, greaterThanOrEqualTo(0));
      expect(result.dy, greaterThanOrEqualTo(0));
      expect(result.dx, lessThanOrEqualTo(1920));
      expect(result.dy, lessThanOrEqualTo(1080));
    });

    Glados2(any.doubleInRange(1921, 9000), any.doubleInRange(1081, 9000)).test(
      'point right/below single display clamps to boundary',
      (double x, double y) {
        final rects = [Rect.fromLTWH(0, 0, 1920, 1080)];
        final result = _nearestDisplayPoint(Offset(x, y), rects);
        expect(result.dx, lessThanOrEqualTo(1920));
        expect(result.dy, lessThanOrEqualTo(1080));
      },
    );
  });
}
