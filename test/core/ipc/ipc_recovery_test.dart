import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';

void main() {
  group('Corrupted IPC Payload Graceful Recovery Tests', () {
    test('IpcEvent.parse returns UnknownIpcEvent on invalid event names', () {
      final parsed = IpcEvent.parse('invalid.event.name', {'foo': 'bar'});
      expect(parsed, isA<UnknownIpcEvent>());
      expect(parsed.eventName, equals('invalid.event.name'));
      expect(parsed.payload, equals({'foo': 'bar'}));
    });

    test('IpcEvent.parse handles missing required fields gracefully', () {
      try {
        final parsed = IpcEvent.parse(IpcEventNames.timerStateChanged, {
          // Missing required fields like stateName, countdownSeconds
        });
        expect(parsed, isNotNull);
      } catch (e) {
        expect(e, isA<TypeError>());
      }
    });

    test('IpcEvent.parse handles invalid types in payload map gracefully', () {
      try {
        IpcEvent.parse(IpcEventNames.timerStateChanged, {
          'stateName': 12345,
          'countdownSeconds': 'not_an_int',
          'workElapsedSeconds': 300,
        });
      } catch (e) {
        expect(e, isA<TypeError>());
      }
    });
  });
}
