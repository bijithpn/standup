import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';

void main() {
  group('IPC Events Serialization & Deserialization', () {
    test('TimerStateChangedIpcEvent serialization and deserialization', () {
      final original = IpcEvent.timerStateChanged(
        stateName: 'running',
        countdownSeconds: 1200,
        workElapsedSeconds: 300,
        targetEndTime: 1680000000000,
        totalWorkTodaySeconds: 7200,
      );

      expect(original.eventName, equals(IpcEventNames.timerStateChanged));

      final payload = original.payload;
      expect(payload['stateName'], equals('running'));
      expect(payload['countdownSeconds'], equals(1200));
      expect(payload['workElapsedSeconds'], equals(300));
      expect(payload['targetEndTime'], equals(1680000000000));
      expect(payload['totalWorkTodaySeconds'], equals(7200));

      final parsed =
          IpcEvent.parse(original.eventName, payload)
              as TimerStateChangedIpcEvent;

      expect(parsed.stateName, equals('running'));
      expect(parsed.countdownSeconds, equals(1200));
      expect(parsed.workElapsedSeconds, equals(300));
      expect(parsed.targetEndTime, equals(1680000000000));
      expect(parsed.totalWorkTodaySeconds, equals(7200));
    });

    test('BreakStartedIpcEvent serialization and deserialization', () {
      final original = IpcEvent.breakStarted(
        isLongBreak: true,
        durationSeconds: 900,
        title: 'Lunch Break',
      );

      expect(original.eventName, equals(IpcEventNames.breakStarted));

      final payload = original.payload;
      expect(payload['isLongBreak'], isTrue);
      expect(payload['durationSeconds'], equals(900));
      expect(payload['title'], equals('Lunch Break'));

      final parsed =
          IpcEvent.parse(original.eventName, payload) as BreakStartedIpcEvent;

      expect(parsed.isLongBreak, isTrue);
      expect(parsed.durationSeconds, equals(900));
      expect(parsed.title, equals('Lunch Break'));
    });

    test('BreakEndedIpcEvent serialization and deserialization', () {
      final original = IpcEvent.breakEnded(skipped: true);

      expect(original.eventName, equals(IpcEventNames.breakEnded));

      final payload = original.payload;
      expect(payload['skipped'], isTrue);

      final parsed =
          IpcEvent.parse(original.eventName, payload) as BreakEndedIpcEvent;

      expect(parsed.skipped, isTrue);
    });

    test('CompanionInteractionIpcEvent serialization and deserialization', () {
      final original = IpcEvent.companionInteraction(
        interactionType: 'pet',
        metadata: {'petName': 'Mochi'},
      );

      expect(original.eventName, equals(IpcEventNames.companionInteraction));

      final payload = original.payload;
      expect(payload['interactionType'], equals('pet'));
      expect(payload['metadata'], equals({'petName': 'Mochi'}));

      final parsed =
          IpcEvent.parse(original.eventName, payload)
              as CompanionInteractionIpcEvent;

      expect(parsed.interactionType, equals('pet'));
      expect(parsed.metadata, equals({'petName': 'Mochi'}));
    });

    test('MeetingDetectedIpcEvent serialization and deserialization', () {
      final original = IpcEvent.meetingDetected(
        isActive: true,
        bundleId: 'com.apple.zoom',
      );

      expect(original.eventName, equals(IpcEventNames.detectionMeeting));

      final payload = original.payload;
      expect(payload['isActive'], isTrue);
      expect(payload['bundleId'], equals('com.apple.zoom'));

      final parsed =
          IpcEvent.parse(original.eventName, payload)
              as MeetingDetectedIpcEvent;

      expect(parsed.isActive, isTrue);
      expect(parsed.bundleId, equals('com.apple.zoom'));
    });

    test('TrayActionIpcEvent serialization and deserialization', () {
      final original = IpcEvent.trayAction(action: 'click');

      expect(original.eventName, equals(IpcEventNames.trayAction));

      final payload = original.payload;
      expect(payload['action'], equals('click'));

      final parsed =
          IpcEvent.parse(original.eventName, payload) as TrayActionIpcEvent;

      expect(parsed.action, equals('click'));
    });

    test('CompanionCloseIpcEvent serialization and deserialization', () {
      final original = IpcEvent.companionClose();

      expect(original.eventName, equals(IpcEventNames.companionClose));

      final parsed =
          IpcEvent.parse(original.eventName, {}) as CompanionCloseIpcEvent;

      expect(parsed, isNotNull);
    });

    test(
      'CompanionPositionChangedIpcEvent serialization and deserialization',
      () {
        final original = IpcEvent.companionPositionChanged(x: 12.5, y: 88.0);

        expect(
          original.eventName,
          equals(IpcEventNames.companionPositionChanged),
        );

        final payload = original.payload;
        expect(payload['x'], equals(12.5));
        expect(payload['y'], equals(88.0));

        final parsed =
            IpcEvent.parse(original.eventName, payload)
                as CompanionPositionChangedIpcEvent;

        expect(parsed.x, equals(12.5));
        expect(parsed.y, equals(88.0));
      },
    );

    test('CompanionStateChangedIpcEvent serialization and deserialization', () {
      final original = IpcEvent.companionStateChanged(state: 'walking');

      expect(original.eventName, equals(IpcEventNames.companionStateChanged));

      final payload = original.payload;
      expect(payload['state'], equals('walking'));

      final parsed =
          IpcEvent.parse(original.eventName, payload)
              as CompanionStateChangedIpcEvent;

      expect(parsed.state, equals('walking'));
    });

    test('UnknownIpcEvent parsed for unrecognized event names', () {
      final parsed = IpcEvent.parse('some.unknown.event', {'data': 123});
      expect(parsed, isA<UnknownIpcEvent>());
      expect(parsed.eventName, equals('some.unknown.event'));
      expect(parsed.payload, equals({'data': 123}));
    });
  });
}
