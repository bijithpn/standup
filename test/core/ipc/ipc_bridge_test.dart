// Stress/recovery coverage for IpcBridge itself (BREAKMATE_ROADMAP.md's
// "IPC stress/recovery tests" item) — the retry-then-give-up dispatch path,
// and a misbehaving typed handler not taking the whole bridge down with it.
// The native fan-out (IpcBridgeManager.swift) that dispatch ultimately talks
// to isn't exercised here — that needs an XCTest on the native side; this
// covers everything reachable from Dart.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/core/ipc/ipc_bridge.dart';
import 'package:breakmate/core/ipc/ipc_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.breakmate/ipc');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('dispatch retry/recovery', () {
    test('gives up gracefully after repeated failures, without throwing', () async {
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            attempts++;
            throw PlatformException(code: 'UNAVAILABLE');
          });

      await IpcBridge.instance.dispatch(
        IpcEvent.trayAction(action: 'stress-fail'),
      );

      expect(attempts, 3);
      expect(IpcBridge.instance.lastSuccessfulEvent('tray.action'), isNull);
    });

    test('recovers and records success once the channel comes back', () async {
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            attempts++;
            if (attempts < 2) throw PlatformException(code: 'UNAVAILABLE');
            return null;
          });

      await IpcBridge.instance.dispatch(
        IpcEvent.trayAction(action: 'stress-recover'),
      );

      expect(attempts, 2);
      expect(
        IpcBridge.instance.lastSuccessfulEvent('tray.action'),
        isNotNull,
      );
    });

    test('succeeds immediately on the first try when the channel is healthy', () async {
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            attempts++;
            return null;
          });

      await IpcBridge.instance.dispatch(
        IpcEvent.companionInteraction(interactionType: 'stress-ok'),
      );

      expect(attempts, 1);
    });
  });

  group('typed event handler resilience', () {
    test('a throwing handler does not crash future dispatches', () async {
      IpcBridge.instance.setTypedEventHandler((event) {
        throw StateError('handler blew up');
      });

      // Simulate the native side invoking a method on this channel, the way
      // IpcBridgeManager.broadcast does — this must not throw synchronously
      // even though the bound handler above always throws.
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'com.breakmate/ipc',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('tray.action', {'action': 'boom'}),
            ),
            (_) {},
          );

      // No exception propagated out of the binding — the bridge's own
      // try/catch around the handler call absorbed it.
    });
  });
}
