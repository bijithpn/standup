// Task 5.2 — Unit tests for FallbackBridge PAL stubs
// Requirement 1.8 — safe defaults without throwing

import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/native/native_bridge.dart';

void main() {
  group('FallbackBridge PAL stubs (Task 5.2)', () {
    late FallbackBridge bridge;
    setUp(() => bridge = const FallbackBridge());

    test('enumerateDisplays returns empty list', () async {
      final result = await bridge.enumerateDisplays();
      expect(result, isEmpty);
    });

    test('registerDisplayChangeCallback does not throw', () {
      expect(
        () => bridge.registerDisplayChangeCallback((_) {}),
        returnsNormally,
      );
    });

    test('getCursorPosition returns Offset.zero', () async {
      final pos = await bridge.getCursorPosition();
      expect(pos.dx, equals(0.0));
      expect(pos.dy, equals(0.0));
    });

    test('getVisibleWindows returns empty list', () async {
      final result = await bridge.getVisibleWindows();
      expect(result, isEmpty);
    });

    test('showConstraintWindow does not throw', () async {
      expect(
        () async => bridge.showConstraintWindow({'x': 0, 'y': 0, 'width': 300, 'height': 300}),
        returnsNormally,
      );
    });

    test('hideConstraintWindow does not throw', () async {
      expect(() async => bridge.hideConstraintWindow(), returnsNormally);
    });

    test('registerConstraintWindowBoundsCallback does not throw', () {
      expect(
        () => bridge.registerConstraintWindowBoundsCallback((_) {}),
        returnsNormally,
      );
    });

    test('showPipWindow does not throw', () async {
      expect(
        () async => bridge.showPipWindow({'width': 280, 'height': 320}),
        returnsNormally,
      );
    });

    test('hidePipWindow does not throw', () async {
      expect(() async => bridge.hidePipWindow(), returnsNormally);
    });
  });
}
