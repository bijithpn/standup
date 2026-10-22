// Regression coverage for the Windows meeting-detection fallback: no native
// bridge exists for `com.breakmate/meeting_detection` on Windows, so
// [MeetingDetectionService] must fall back to polling
// [AppTrackingService.getActiveApp] against [kKnownMeetingApps] instead of
// silently staying `false` forever (the bug this fallback replaces).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/native/app_tracking_service.dart';
import 'package:breakmate/core/native/meeting_detection_service.dart';

class FakeAppTrackingService implements AppTrackingService {
  ActiveAppInfo? nextApp;

  @override
  Future<ActiveAppInfo?> getActiveApp({
    bool includeTitle = false,
    bool includeUrl = false,
  }) async => nextApp;

  @override
  Future<Uint8List?> getAppIcon({
    String? bundleId,
    String? executableName,
  }) async => null;
}

void main() {
  late FakeAppTrackingService fakeTracking;
  late MeetingDetectionService service;

  setUp(() {
    fakeTracking = FakeAppTrackingService();
    service = MeetingDetectionService(appTracking: fakeTracking);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('kKnownMeetingApps matching (Windows polling fallback)', () {
    test('Zoom.exe is recognized as a meeting app', () async {
      fakeTracking.nextApp = ActiveAppInfo(
        name: 'Zoom',
        bundleId: 'Unknown',
        executableName: 'Zoom.exe',
      );
      await service.pollOnceForTest();
      expect(service.isMeetingActive, isTrue);
    });

    test('Microsoft Teams exe is recognized as a meeting app', () async {
      fakeTracking.nextApp = ActiveAppInfo(
        name: 'Microsoft Teams',
        bundleId: 'Unknown',
        executableName: 'ms-teams.exe',
      );
      await service.pollOnceForTest();
      expect(service.isMeetingActive, isTrue);
    });

    test('an unrelated app is not recognized as a meeting app', () async {
      fakeTracking.nextApp = ActiveAppInfo(
        name: 'Visual Studio Code',
        bundleId: 'Unknown',
        executableName: 'Code.exe',
      );
      await service.pollOnceForTest();
      expect(service.isMeetingActive, isFalse);
    });

    test('macOS bundle ids still match via substring', () async {
      fakeTracking.nextApp = ActiveAppInfo(
        name: 'zoom.us',
        bundleId: 'us.zoom.xos',
        executableName: 'Unknown',
      );
      await service.pollOnceForTest();
      expect(service.isMeetingActive, isTrue);
    });

    test('a null active app leaves the previous state unchanged', () async {
      fakeTracking.nextApp = ActiveAppInfo(
        name: 'Zoom',
        bundleId: 'Unknown',
        executableName: 'Zoom.exe',
      );
      await service.pollOnceForTest();
      expect(service.isMeetingActive, isTrue);

      fakeTracking.nextApp = null;
      await service.pollOnceForTest();
      expect(service.isMeetingActive, isTrue);
    });
  });

  group('isMeetingActiveStream', () {
    test('emits polled results while running on Windows', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final events = <bool>[];
      final sub = service.isMeetingActiveStream.listen(events.add);

      fakeTracking.nextApp = ActiveAppInfo(
        name: 'Slack',
        bundleId: 'Unknown',
        executableName: 'slack.exe',
      );
      service.start();
      addTearDown(service.stop);
      addTearDown(sub.cancel);

      // start() fires an immediate unawaited poll.
      await Future<void>.delayed(Duration.zero);
      expect(events, contains(true));
    });

    test('emits polled results while running on Linux', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final events = <bool>[];
      final sub = service.isMeetingActiveStream.listen(events.add);

      fakeTracking.nextApp = ActiveAppInfo(
        name: 'Zoom',
        bundleId: 'zoom',
        executableName: 'zoom',
      );
      service.start();
      addTearDown(service.stop);
      addTearDown(sub.cancel);

      // start() fires an immediate unawaited poll.
      await Future<void>.delayed(Duration.zero);
      expect(events, contains(true));
    });

    test(
      'stop() clears isMeetingActive without emitting through the stream',
      () {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        service.start();
        service.stop();
        expect(service.isMeetingActive, isFalse);
      },
    );
  });
}
