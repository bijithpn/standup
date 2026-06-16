// Integration test: display enumeration timing
//
// Verifies that DisplayManager.enumerateDisplays() completes within 500 ms
// even when the underlying native bridge takes 400 ms to respond.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';

// ---------------------------------------------------------------------------
// Mock bridge that delays enumerateDisplays() by 400 ms then returns data
// ---------------------------------------------------------------------------

/// A mock [NativeBridgePlatform] that simulates a 400 ms native enumeration
/// round-trip and returns two valid display maps.
class _SlowDisplayBridge extends FallbackBridge {
  static const _delay = Duration(milliseconds: 400);

  static const List<Map<String, dynamic>> _fakeDisplays = [
    {
      'id': 'display-1',
      'x': 0.0,
      'y': 0.0,
      'width': 1920.0,
      'height': 1080.0,
      'dpiScale': 1.0,
      'isPrimary': true,
    },
    {
      'id': 'display-2',
      'x': 1920.0,
      'y': 0.0,
      'width': 2560.0,
      'height': 1440.0,
      'dpiScale': 2.0,
      'isPrimary': false,
    },
  ];

  @override
  Future<List<NativeDisplayInfo>> enumerateDisplays() async {
    await Future<void>.delayed(_delay);
    return _fakeDisplays.map((map) => NativeDisplayInfo.fromMap(map)).toList();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DisplayManager.enumerateDisplays() — timing and parsing (Task 20.2)', () {
    late _SlowDisplayBridge mockBridge;
    late NativeDisplayManager displayManager;

    setUp(() {
      mockBridge = _SlowDisplayBridge();
      displayManager = NativeDisplayManager(bridge: mockBridge);
    });

    test(
      'completes within 500 ms when native bridge takes 400 ms (Req 1.5)',
      () async {
        final stopwatch = Stopwatch()..start();
        await displayManager.enumerateDisplays();
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(500),
          reason:
              'enumerateDisplays() must complete in < 500 ms (Req 1.5); '
              'took ${stopwatch.elapsedMilliseconds} ms',
        );
      },
    );

    // ---- Parsing correctness -------------------------------------------------

    test('returns the correct number of displays', () async {
      final displays = await displayManager.enumerateDisplays();
      expect(displays, hasLength(2));
    });

    test('primary display is parsed correctly', () async {
      final displays = await displayManager.enumerateDisplays();
      final primary = displays.firstWhere((d) => d.isPrimary);

      expect(primary.id, equals('display-1'));
      expect(primary.rect, equals(const Rect.fromLTWH(0, 0, 1920, 1080)));
      expect(primary.dpiScale, equals(1.0));
      expect(primary.isPrimary, isTrue);
    });

    test('secondary display is parsed correctly', () async {
      final displays = await displayManager.enumerateDisplays();
      final secondary = displays.firstWhere((d) => !d.isPrimary);

      expect(secondary.id, equals('display-2'));
      expect(secondary.rect, equals(const Rect.fromLTWH(1920, 0, 2560, 1440)));
      expect(secondary.dpiScale, equals(2.0));
      expect(secondary.isPrimary, isFalse);
    });

    test('returned list is unmodifiable', () async {
      final displays = await displayManager.enumerateDisplays();
      // The list is unmodifiable — any mutation attempt throws.
      // We supply a typed element to avoid a _TypeError masking the real error.
      const dummy = DisplayBounds(
        id: 'dummy',
        rect: Rect.fromLTWH(0, 0, 1, 1),
        dpiScale: 1.0,
        isPrimary: false,
      );
      expect(() => (displays as dynamic).add(dummy), throwsUnsupportedError);
    });

    // ---- unionBounds is updated after enumeration ----------------------------

    test('unionBounds spans all displays after enumeration', () async {
      await displayManager.enumerateDisplays();

      // Union of [0,0,1920,1080] and [1920,0,2560,1440]:
      //   left=0, top=0, right=1920+2560=4480, bottom=max(1080,1440)=1440
      const expectedUnion = Rect.fromLTWH(0, 0, 4480, 1440);
      expect(displayManager.unionBounds, equals(expectedUnion));
    });

    // ---- Returns a DisplayBounds list (not raw maps) -------------------------

    test('result elements are DisplayBounds instances', () async {
      final displays = await displayManager.enumerateDisplays();
      for (final d in displays) {
        expect(d, isA<DisplayBounds>());
      }
    });
  });
}
