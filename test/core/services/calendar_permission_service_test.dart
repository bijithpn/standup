import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:breakmate/core/native/native_bridge.dart';
import 'package:breakmate/core/services/calendar_permission_service.dart';

class MockNativeBridgePlatform extends Mock implements NativeBridgePlatform {}

void main() {
  group('CalendarPermissionService Tests', () {
    late MockNativeBridgePlatform mockPlatform;
    late CalendarPermissionService service;

    setUp(() {
      mockPlatform = MockNativeBridgePlatform();
      service = CalendarPermissionService(platform: mockPlatform);
    });

    test(
      'getStatus: returns correct status mapping from platform status strings',
      () async {
        // notDetermined
        when(
          () => mockPlatform.getCalendarPermissionStatus(),
        ).thenAnswer((_) async => 'notDetermined');
        expect(
          await service.getStatus(),
          equals(CalendarPermissionStatus.notDetermined),
        );

        // restricted
        when(
          () => mockPlatform.getCalendarPermissionStatus(),
        ).thenAnswer((_) async => 'restricted');
        expect(
          await service.getStatus(),
          equals(CalendarPermissionStatus.restricted),
        );

        // granted
        when(
          () => mockPlatform.getCalendarPermissionStatus(),
        ).thenAnswer((_) async => 'granted');
        expect(
          await service.getStatus(),
          equals(CalendarPermissionStatus.granted),
        );
      },
    );

    test('getStatus: soft-denial vs permanently-denied behavior', () async {
      // 1. Without requestPermission, denied is permanentlyDenied
      when(
        () => mockPlatform.getCalendarPermissionStatus(),
      ).thenAnswer((_) async => 'denied');
      expect(
        await service.getStatus(),
        equals(CalendarPermissionStatus.permanentlyDenied),
      );

      // 2. Request permission successfully sets session flag
      when(
        () => mockPlatform.requestCalendarPermissions(),
      ).thenAnswer((_) async => false);
      expect(await service.requestPermission(), isFalse);

      // 3. With requestPermission session flag, status is soft denied
      expect(
        await service.getStatus(),
        equals(CalendarPermissionStatus.denied),
      );

      // 4. resetRequestSession resets session flag, making status permanentlyDenied again
      service.resetRequestSession();
      expect(
        await service.getStatus(),
        equals(CalendarPermissionStatus.permanentlyDenied),
      );
    });

    test('getStatus: handles errors gracefully by returning denied', () async {
      when(
        () => mockPlatform.getCalendarPermissionStatus(),
      ).thenThrow(Exception('Native error'));
      expect(
        await service.getStatus(),
        equals(CalendarPermissionStatus.denied),
      );
    });

    test('requestPermission: calls platform and returns boolean', () async {
      when(
        () => mockPlatform.requestCalendarPermissions(),
      ).thenAnswer((_) async => true);
      expect(await service.requestPermission(), isTrue);

      when(
        () => mockPlatform.requestCalendarPermissions(),
      ).thenAnswer((_) async => false);
      expect(await service.requestPermission(), isFalse);
    });

    test(
      'requestPermission: handles platform errors and returns false',
      () async {
        when(
          () => mockPlatform.requestCalendarPermissions(),
        ).thenThrow(Exception('Platform dialog crashed'));
        expect(await service.requestPermission(), isFalse);
      },
    );

    test('openSettings: triggers platform settings redirect', () async {
      when(() => mockPlatform.openCalendarSettings()).thenAnswer((_) async {});

      await expectLater(service.openSettings(), completes);
      verify(() => mockPlatform.openCalendarSettings()).called(1);
    });

    test('openSettings: handles errors gracefully', () async {
      when(
        () => mockPlatform.openCalendarSettings(),
      ).thenThrow(Exception('OS settings unavailable'));

      await expectLater(service.openSettings(), completes);
      verify(() => mockPlatform.openCalendarSettings()).called(1);
    });
  });
}
