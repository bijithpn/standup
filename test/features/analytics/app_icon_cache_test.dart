import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/features/analytics/app_icon_cache.dart';

class MockAppTrackingService extends Mock implements AppTrackingService {}

void main() {
  late MockAppTrackingService mockTracking;
  late AppIconCache cache;

  setUp(() {
    mockTracking = MockAppTrackingService();
    cache = AppIconCache(appTracking: mockTracking);
  });

  test('fetches the icon once and caches it for subsequent calls', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    when(
      () => mockTracking.getAppIcon(bundleId: 'com.example.app', executableName: null),
    ).thenAnswer((_) async => bytes);

    final first = await cache.iconFor(appKey: 'com.example.app', bundleId: 'com.example.app');
    final second = await cache.iconFor(appKey: 'com.example.app', bundleId: 'com.example.app');

    expect(first, bytes);
    expect(second, bytes);
    verify(
      () => mockTracking.getAppIcon(bundleId: 'com.example.app', executableName: null),
    ).called(1);
  });

  test('caches a null result too, so a failed fetch is not retried', () async {
    when(
      () => mockTracking.getAppIcon(bundleId: 'missing', executableName: null),
    ).thenAnswer((_) async => null);

    final first = await cache.iconFor(appKey: 'missing', bundleId: 'missing');
    final second = await cache.iconFor(appKey: 'missing', bundleId: 'missing');

    expect(first, isNull);
    expect(second, isNull);
    verify(
      () => mockTracking.getAppIcon(bundleId: 'missing', executableName: null),
    ).called(1);
  });
}
