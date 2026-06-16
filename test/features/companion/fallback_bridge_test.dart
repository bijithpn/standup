import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/native/native_bridge.dart';

// FallbackBridge provides stubs for non-supported desktop platforms or local execution.
// This ensures that unit tests and basic dashboard rendering run successfully on developer machines
// and in headless CI/CD automation without crashing due to unavailable native method channels.
void main() {
  group('FallbackBridge PAL stubs (Task 5.2)', () {
    late FallbackBridge bridge;
    setUp(() => bridge = const FallbackBridge());

    test('enumerateDisplays returns empty list of NativeDisplayInfo', () async {
      final result = await bridge.enumerateDisplays();
      expect(result, isA<List<NativeDisplayInfo>>());
      expect(result, isEmpty);
    });

    test('NativeDisplayInfo parsing handles custom display maps correctly', () {
      final map = {
        'id': 'mock_display_1',
        'x': 0.0,
        'y': 0.0,
        'width': 1920.0,
        'height': 1080.0,
        'dpiScale': 2.0,
        'isPrimary': true,
      };
      final display = NativeDisplayInfo.fromMap(map);
      expect(display.id, equals('mock_display_1'));
      expect(display.x, equals(0.0));
      expect(display.y, equals(0.0));
      expect(display.width, equals(1920.0));
      expect(display.height, equals(1080.0));
      expect(display.dpiScale, equals(2.0));
      expect(display.isPrimary, isTrue);
    });

    test('registerDisplayChangeCallback does not throw', () {
      expect(
        () => bridge.registerDisplayChangeCallback((_) {}),
        returnsNormally,
      );
    });

    test('getCursorPosition returns Offset.zero and is type Offset', () async {
      final pos = await bridge.getCursorPosition();
      expect(pos, isA<Offset>());
      expect(pos.dx, equals(0.0));
      expect(pos.dy, equals(0.0));
    });

    test('getVisibleWindows returns empty list of WindowInfo', () async {
      final result = await bridge.getVisibleWindows();
      expect(result, isA<List<WindowInfo>>());
      expect(result, isEmpty);
    });

    test('getIdleTime returns 0.0 double and is non-null', () async {
      final result = await bridge.getIdleTime();
      expect(result, isA<double>());
      expect(result, equals(0.0));
    });

    test('getAppearance returns non-empty String appearance default', () async {
      final result = await bridge.getAppearance();
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });

    test(
      'calendar permission stubs return non-null expected defaults',
      () async {
        expect(await bridge.requestCalendarPermissions(), isFalse);
        expect(await bridge.hasCalendarPermissions(), isFalse);
        expect(await bridge.getCalendarPermissionStatus(), equals('denied'));
      },
    );

    test(
      'calendar query stubs return non-null empty lists matching types',
      () async {
        final upcoming = await bridge.getUpcomingCalendarEvents(15);
        expect(upcoming, isA<List<Map<String, dynamic>>>());
        expect(upcoming, isEmpty);

        final calendars = await bridge.getCalendars();
        expect(calendars, isA<List<Map<String, dynamic>>>());
        expect(calendars, isEmpty);

        final events = await bridge.getEvents(0, 1000, null);
        expect(events, isA<List<Map<String, dynamic>>>());
        expect(events, isEmpty);
      },
    );

    test('showConstraintWindow does not throw', () async {
      expect(
        () async => bridge.showConstraintWindow(
          ConstraintWindowArgs(x: 0, y: 0, width: 300, height: 300),
        ),
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
        () async => bridge.showPipWindow(
          PipWindowArgs(
            x: 0,
            y: 0,
            width: 280,
            height: 320,
            themeId: 'grey_cat',
            petName: 'Mochi',
            scale: 6.0,
          ),
        ),
        returnsNormally,
      );
    });

    test('hidePipWindow does not throw', () async {
      expect(() async => bridge.hidePipWindow(), returnsNormally);
    });
  });
}
