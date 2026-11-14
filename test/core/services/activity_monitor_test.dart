import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:breakmate/core/services/activity_monitor.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.breakmate.desktop/bridge');

  late MockSettingsRepository repo;
  late ActivityMonitor monitor;
  late List<String> log;
  double? idle;
  bool? locked;

  void useSettings(SettingsModel s) => when(() => repo.currentSettings).thenReturn(s);

  setUp(() {
    repo = MockSettingsRepository();
    useSettings(const SettingsModel());
    GetIt.I.registerSingleton<SettingsRepository>(repo);
    idle = 0;
    locked = null;
    log = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getIdleTime') {
        if (idle == null) throw PlatformException(code: 'IDLE_UNAVAILABLE');
        return idle;
      }
      if (call.method == 'getSessionState') {
        return locked == null ? <String, dynamic>{} : {'locked': locked};
      }
      return null;
    });
    monitor = ActivityMonitor()
      ..setActivityCallback((active) => log.add(active ? 'active' : 'idle'))
      ..setAwayCallbacks(
        onAway: (_) => log.add('away'),
        onBack: () => log.add('back'),
      );
  });

  tearDown(() {
    monitor.dispose();
    GetIt.I.reset();
  });

  void run(void Function(FakeAsync async) body) => fakeAsync((async) {
        monitor.start();
        async.elapse(const Duration(milliseconds: 10));
        body(async);
        monitor.stop();
      });

  void tick(FakeAsync a, [int seconds = 6]) => a.elapse(Duration(seconds: seconds));

  test('idle past the threshold pauses once, input resumes once', () {
    run((a) {
      idle = 301;
      tick(a, 12);
      expect(log, ['idle']);
      idle = 1;
      tick(a);
      expect(log, ['idle', 'active']);
    });
  });

  test('threshold change applies without restart', () {
    run((a) {
      idle = 130;
      tick(a);
      expect(log, isEmpty);
      useSettings(const SettingsModel(pauseTimerAfterMinutes: 2));
      tick(a);
      expect(log, ['idle']);
    });
  });

  test('auto-pause disabled never pauses on idle', () {
    useSettings(const SettingsModel(autoPauseOnIdle: false));
    run((a) {
      idle = 9999;
      tick(a);
      expect(log, isEmpty);
    });
  });

  test('wake while still locked stays away; unlock plus input returns', () {
    run((a) {
      monitor.handleNative('sessionLocked');
      monitor.handleNative('systemSleep');
      monitor.handleNative('systemSleep');
      monitor.handleNative('systemWake');
      idle = 0;
      tick(a);
      expect(log, ['away']);
      expect(monitor.isIdle, isTrue);

      monitor.handleNative('sessionUnlocked');
      idle = 60;
      tick(a);
      expect(log, ['away']);
      idle = 1;
      tick(a);
      expect(log, ['away', 'back']);
      expect(monitor.isIdle, isFalse);
    });
  });

  test('wake alone is not proof of activity', () {
    run((a) {
      monitor.handleNative('systemSleep');
      monitor.handleNative('systemWake');
      idle = 3600;
      tick(a, 30);
      expect(log, ['away']);
    });
  });

  test('lock ignored when pause-on-lock is off', () {
    useSettings(const SettingsModel(pauseOnLock: false));
    run((a) {
      monitor.handleNative('sessionLocked');
      tick(a);
      expect(log, isEmpty);
    });
  });

  test('missed lock event is recovered from the session query', () {
    run((a) {
      locked = true;
      tick(a);
      expect(log, ['away']);
      locked = false;
      idle = 0;
      tick(a);
      expect(log, ['away', 'back']);
    });
  });

  test('rapid transitions end consistent', () {
    run((a) {
      idle = 400;
      tick(a);
      idle = 0;
      tick(a);
      monitor.handleNative('sessionLocked');
      monitor.handleNative('systemSleep');
      monitor.handleNative('systemWake');
      monitor.handleNative('sessionLocked');
      monitor.handleNative('sessionUnlocked');
      tick(a);
      expect(log, ['idle', 'active', 'away', 'back']);
      expect(monitor.awayReasons, isEmpty);
    });
  });

  test('no idle provider is reported and does not fake activity', () {
    run((a) {
      idle = null;
      tick(a);
      expect(monitor.idleSupported, isFalse);
      monitor.handleNative('sessionLocked');
      monitor.handleNative('sessionUnlocked');
      tick(a, 2);
      expect(log, ['away', 'back']);
    });
  });
}
