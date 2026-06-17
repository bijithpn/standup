import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';

void main() {
  group('IPC Events Serialization & Deserialization', () {
    test('TimerStateChangedIpcEvent serialization and deserialization', () {
      final original = TimerStateChangedIpcEvent(
        stateName: 'running',
        countdownSeconds: 1200,
        workElapsedSeconds: 300,
        targetEndTime: 1680000000000,
        totalWorkTodaySeconds: 7200,
      );

      final json = original.toJson();
      expect(json['eventName'], equals(IpcEventNames.timerStateChanged));
      expect(json['version'], equals(IpcEvent.currentVersion));

      final payload = json['payload'] as Map<String, dynamic>;
      expect(payload['state'], equals('running'));
      expect(payload['countdownSeconds'], equals(1200));
      expect(payload['workElapsedSeconds'], equals(300));
      expect(payload['targetEndTime'], equals(1680000000000));
      expect(payload['totalWorkTodaySeconds'], equals(7200));

      final parsed =
          IpcEvent.parse(json['eventName'] as String, payload)
              as TimerStateChangedIpcEvent;

      expect(parsed.stateName, equals('running'));
      expect(parsed.countdownSeconds, equals(1200));
      expect(parsed.workElapsedSeconds, equals(300));
      expect(parsed.targetEndTime, equals(1680000000000));
      expect(parsed.totalWorkTodaySeconds, equals(7200));
    });

    test('BreakStartedIpcEvent serialization and deserialization', () {
      final original = BreakStartedIpcEvent(
        isLongBreak: true,
        durationSeconds: 900,
        title: 'Lunch Break',
      );

      final json = original.toJson();
      expect(json['eventName'], equals(IpcEventNames.breakStarted));

      final payload = json['payload'] as Map<String, dynamic>;
      expect(payload['isLongBreak'], isTrue);
      expect(payload['durationSeconds'], equals(900));
      expect(payload['title'], equals('Lunch Break'));

      final parsed =
          IpcEvent.parse(json['eventName'] as String, payload)
              as BreakStartedIpcEvent;

      expect(parsed.isLongBreak, isTrue);
      expect(parsed.durationSeconds, equals(900));
      expect(parsed.title, equals('Lunch Break'));
    });

    test('BreakEndedIpcEvent serialization and deserialization', () {
      final original = BreakEndedIpcEvent(skipped: true);

      final json = original.toJson();
      expect(json['eventName'], equals(IpcEventNames.breakEnded));

      final payload = json['payload'] as Map<String, dynamic>;
      expect(payload['skipped'], isTrue);

      final parsed =
          IpcEvent.parse(json['eventName'] as String, payload)
              as BreakEndedIpcEvent;

      expect(parsed.skipped, isTrue);
    });

    test('CompanionInteractionIpcEvent serialization and deserialization', () {
      final original = CompanionInteractionIpcEvent(
        interactionType: 'pet',
        metadata: {'petName': 'Mochi'},
      );

      final json = original.toJson();
      expect(json['eventName'], equals(IpcEventNames.companionInteraction));

      final payload = json['payload'] as Map<String, dynamic>;
      expect(payload['interactionType'], equals('pet'));
      expect(payload['metadata'], equals({'petName': 'Mochi'}));

      final parsed =
          IpcEvent.parse(json['eventName'] as String, payload)
              as CompanionInteractionIpcEvent;

      expect(parsed.interactionType, equals('pet'));
      expect(parsed.metadata, equals({'petName': 'Mochi'}));
    });

    test('MeetingDetectedIpcEvent serialization and deserialization', () {
      final original = MeetingDetectedIpcEvent(
        isActive: true,
        bundleId: 'com.apple.zoom',
      );

      final json = original.toJson();
      expect(json['eventName'], equals(IpcEventNames.detectionMeeting));

      final payload = json['payload'] as Map<String, dynamic>;
      expect(payload['isActive'], isTrue);
      expect(payload['bundleId'], equals('com.apple.zoom'));

      final parsed =
          IpcEvent.parse(json['eventName'] as String, payload)
              as MeetingDetectedIpcEvent;

      expect(parsed.isActive, isTrue);
      expect(parsed.bundleId, equals('com.apple.zoom'));
    });

    test('FocusModeIpcEvent serialization and deserialization', () {
      final original = FocusModeIpcEvent(isActive: true);

      final json = original.toJson();
      expect(json['eventName'], equals(IpcEventNames.detectionFocusMode));

      final payload = json['payload'] as Map<String, dynamic>;
      expect(payload['isActive'], isTrue);

      final parsed =
          IpcEvent.parse(json['eventName'] as String, payload)
              as FocusModeIpcEvent;

      expect(parsed.isActive, isTrue);
    });

    test('TrayActionIpcEvent serialization and deserialization', () {
      final original = TrayActionIpcEvent(action: 'click');

      final json = original.toJson();
      expect(json['eventName'], equals(IpcEventNames.trayAction));

      final payload = json['payload'] as Map<String, dynamic>;
      expect(payload['action'], equals('click'));

      final parsed =
          IpcEvent.parse(json['eventName'] as String, payload)
              as TrayActionIpcEvent;

      expect(parsed.action, equals('click'));
    });

    test('CompanionCloseIpcEvent serialization and deserialization', () {
      final original = CompanionCloseIpcEvent();

      final json = original.toJson();
      expect(json['eventName'], equals(IpcEventNames.companionClose));

      final parsed =
          IpcEvent.parse(json['eventName'] as String, {})
              as CompanionCloseIpcEvent;

      expect(parsed, isNotNull);
    });

    test(
      'CompanionPositionChangedIpcEvent serialization and deserialization',
      () {
        final original = CompanionPositionChangedIpcEvent(x: 12.5, y: 88.0);

        final json = original.toJson();
        expect(
          json['eventName'],
          equals(IpcEventNames.companionPositionChanged),
        );

        final payload = json['payload'] as Map<String, dynamic>;
        expect(payload['x'], equals(12.5));
        expect(payload['y'], equals(88.0));

        final parsed =
            IpcEvent.parse(json['eventName'] as String, payload)
                as CompanionPositionChangedIpcEvent;

        expect(parsed.x, equals(12.5));
        expect(parsed.y, equals(88.0));
      },
    );

    test('CompanionStateChangedIpcEvent serialization and deserialization', () {
      final original = CompanionStateChangedIpcEvent(state: 'walking');

      final json = original.toJson();
      expect(json['eventName'], equals(IpcEventNames.companionStateChanged));

      final payload = json['payload'] as Map<String, dynamic>;
      expect(payload['state'], equals('walking'));

      final parsed =
          IpcEvent.parse(json['eventName'] as String, payload)
              as CompanionStateChangedIpcEvent;

      expect(parsed.state, equals('walking'));
    });

    test('UnknownIpcEvent parsed for unrecognized event names', () {
      final parsed = IpcEvent.parse('some.unknown.event', {'data': 123});
      expect(parsed, isA<UnknownIpcEvent>());
      expect(parsed.eventName, equals('some.unknown.event'));
      expect(parsed.payload, equals({'data': 123}));
    });

    test(
      'FormatException thrown on missing required fields or type mismatches',
      () {
        expect(
          () => TimerStateChangedIpcEvent.fromJson({
            'state': 123,
          }), // should be String
          throwsFormatException,
        );
        expect(
          () => TimerStateChangedIpcEvent.fromJson({
            'countdownSeconds': 10,
          }), // missing 'state'
          throwsFormatException,
        );
      },
    );
  });
}
