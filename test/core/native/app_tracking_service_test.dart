import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.breakmate/app_tracking');
  late int calls;

  setUp(() {
    calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls++;
          return {'name': 'Zoom', 'bundleId': 'us.zoom.xos'};
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('callers within the share window use one native lookup', () async {
    final service = AppTrackingService();
    final a = await service.getActiveApp();
    final b = await service.getActiveApp();
    expect(calls, 1);
    expect(a?.bundleId, 'us.zoom.xos');
    expect(b?.bundleId, 'us.zoom.xos');
  });

  test('concurrent callers share the in-flight lookup', () async {
    final service = AppTrackingService();
    await Future.wait([service.getActiveApp(), service.getActiveApp()]);
    expect(calls, 1);
  });

  test('different detail levels are looked up separately', () async {
    final service = AppTrackingService();
    await service.getActiveApp();
    await service.getActiveApp(includeUrl: true);
    expect(calls, 2);
  });

  test('a lookup after the share window asks the OS again', () async {
    final service = AppTrackingService();
    await withClock(Clock.fixed(DateTime(2026, 1, 1, 12)), () async {
      await service.getActiveApp();
    });
    await withClock(Clock.fixed(DateTime(2026, 1, 1, 12, 0, 2)), () async {
      await service.getActiveApp();
    });
    expect(calls, 2);
  });
}
