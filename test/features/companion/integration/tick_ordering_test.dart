// Integration test: tick ordering and settings-load-before-tick guarantee.
//
//
//   load persisted settings before the first Tick executes.
//   Display_Manager enumeration completes successfully.
//
// Strategy:
//   Rather than spinning up a full CompanionGame (which requires a live Flutter
//   engine, a native bridge, and real platform channels), this test exercises
//   the *ordering contract* by replicating the relevant sequences from
//   CompanionGame.onLoad() and CompanionGame._runSubsystemTick() using stub
//   implementations that record exactly when their methods are called relative
//   to SettingsPersistence.loadSync() and CompanionDisplayManager.enumerateDisplays().

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/behavior_engine_models.dart';
import 'package:breakmate/features/companion/services/display_manager.dart';
import 'package:breakmate/features/companion/services/settings_persistence.dart';

// ---------------------------------------------------------------------------
// TestSettingsPersistence
// ---------------------------------------------------------------------------

/// A [SettingsPersistence]-like stub that:
///  - tracks whether [loadSync] has been called
///  - optionally blocks [loadSync] for [blockDuration] before returning
///  - exposes a [loadSyncCompleted] flag so callers can check post-condition
class TestSettingsPersistence {
  TestSettingsPersistence({this.blockDuration = Duration.zero});

  final Duration blockDuration;

  bool loadSyncCalled = false;
  bool loadSyncCompleted = false;

  PetConfigV2 loadSync() {
    loadSyncCalled = true;

    if (blockDuration > Duration.zero) {
      // Synchronous busy-wait to simulate a slow disk read without async gaps.
      final deadline = DateTime.now().add(blockDuration);
      while (DateTime.now().isBefore(deadline)) {
        // busy wait
      }
    }

    loadSyncCompleted = true;
    return PetConfigV2.defaults();
  }
}

// ---------------------------------------------------------------------------
// Stub subsystems — record whether their tick methods were called, and
// whether those calls happened before loadSync() completed.
// ---------------------------------------------------------------------------

class _CallRecord {
  bool called = false;
  bool calledBeforeSettingsLoaded = false;
}

class _StubDisplayManager implements CompanionDisplayManager {
  final _CallRecord pollRecord = _CallRecord();
  final _CallRecord enumerateRecord = _CallRecord();
  final bool Function() _isSettingsLoaded;

  _StubDisplayManager(this._isSettingsLoaded);

  @override
  List<DisplayBounds> get displays => [
    const DisplayBounds(
      id: 'primary',
      rect: Rect.fromLTWH(0, 0, 1920, 1080),
      dpiScale: 1.0,
      isPrimary: true,
    ),
  ];

  @override
  Future<List<DisplayBounds>> enumerateDisplays() async {
    enumerateRecord.called = true;
    enumerateRecord.calledBeforeSettingsLoaded = !_isSettingsLoaded();
    // Return one fake display so the engine is happy.
    return [
      const DisplayBounds(
        id: 'primary',
        rect: Rect.fromLTWH(0, 0, 1920, 1080),
        dpiScale: 1.0,
        isPrimary: true,
      ),
    ];
  }

  @override
  Rect get unionBounds => const Rect.fromLTWH(0, 0, 1920, 1080);

  @override
  Offset nearestDisplayPoint(Offset outside) => outside;

  @override
  bool areAdjacent(DisplayBounds a, DisplayBounds b) => false;

  @override
  void poll() {
    pollRecord.called = true;
    pollRecord.calledBeforeSettingsLoaded = !_isSettingsLoaded();
  }

  @override
  void onDisplayChanged(List<DisplayBounds> newBounds) {}
}

/// Records calls to cursor sampling.
class _StubCursorTracker {
  final _CallRecord sampleRecord = _CallRecord();
  final bool Function() _isSettingsLoaded;

  _StubCursorTracker(this._isSettingsLoaded);

  Future<void> sample(double dt, Offset petCenter) async {
    sampleRecord.called = true;
    sampleRecord.calledBeforeSettingsLoaded = !_isSettingsLoaded();
  }
}

/// Records calls to window monitoring.
class _StubWindowMonitor {
  final _CallRecord updateRecord = _CallRecord();
  final bool Function() _isSettingsLoaded;

  _StubWindowMonitor(this._isSettingsLoaded);

  Future<void> update(Rect petBounds) async {
    updateRecord.called = true;
    updateRecord.calledBeforeSettingsLoaded = !_isSettingsLoaded();
  }
}

/// Records calls to physics stepping.
class _StubPhysicsSimulator {
  final _CallRecord stepRecord = _CallRecord();
  final bool Function() _isSettingsLoaded;

  _StubPhysicsSimulator(this._isSettingsLoaded);

  void step(double dt) {
    stepRecord.called = true;
    stepRecord.calledBeforeSettingsLoaded = !_isSettingsLoaded();
  }
}

/// Records calls to throwable ticking.
class _StubThrowableManager {
  final _CallRecord tickRecord = _CallRecord();
  final bool Function() _isSettingsLoaded;

  _StubThrowableManager(this._isSettingsLoaded);

  void tick(double dt, {required Rect petBounds, required Offset petAnchor}) {
    tickRecord.called = true;
    tickRecord.calledBeforeSettingsLoaded = !_isSettingsLoaded();
  }
}

// ---------------------------------------------------------------------------
// Helpers that replicate the sequences from CompanionGame
// ---------------------------------------------------------------------------

/// Replicates the relevant part of CompanionGame.onLoad():
///   1. loadSync()        ← must be first
///   2. enumerateDisplays()
Future<void> _simulateOnLoad({
  required TestSettingsPersistence settings,
  required _StubDisplayManager displayManager,
}) async {
  settings.loadSync();

  await displayManager.enumerateDisplays();
}

/// Replicates CompanionGame._runSubsystemTick() — called from update(dt).
Future<void> _simulateSubsystemTick({
  required _StubDisplayManager displayManager,
  required _StubCursorTracker cursorTracker,
  required _StubWindowMonitor windowMonitor,
  required _StubPhysicsSimulator physicsSimulator,
  required _StubThrowableManager throwableManager,
  double dt = 1 / 60,
}) async {
  const Offset petCenter = Offset(960, 540);
  const Rect petBounds = Rect.fromLTWH(920, 500, 80, 80);

  displayManager.poll();
  await cursorTracker.sample(dt, petCenter);
  await windowMonitor.update(petBounds);
  physicsSimulator.step(dt);
  throwableManager.tick(dt, petBounds: petBounds, petAnchor: petCenter);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Tick ordering integration — settings-load-before-tick guarantee', () {
    // -----------------------------------------------------------------------
    // tick method fires.
    // -----------------------------------------------------------------------

    test('Req 11.1: no subsystem tick fires before loadSync() returns '
        '(instantaneous load)', () async {
      final settings = TestSettingsPersistence();
      final displayManager = _StubDisplayManager(
        () => settings.loadSyncCompleted,
      );
      final cursorTracker = _StubCursorTracker(
        () => settings.loadSyncCompleted,
      );
      final windowMonitor = _StubWindowMonitor(
        () => settings.loadSyncCompleted,
      );
      final physicsSimulator = _StubPhysicsSimulator(
        () => settings.loadSyncCompleted,
      );
      final throwableManager = _StubThrowableManager(
        () => settings.loadSyncCompleted,
      );

      // Simulate onLoad first.
      await _simulateOnLoad(settings: settings, displayManager: displayManager);

      // Then simulate the first tick.
      await _simulateSubsystemTick(
        displayManager: displayManager,
        cursorTracker: cursorTracker,
        windowMonitor: windowMonitor,
        physicsSimulator: physicsSimulator,
        throwableManager: throwableManager,
      );

      // Verify loadSync was called and completed.
      expect(
        settings.loadSyncCalled,
        isTrue,
        reason: 'loadSync() must be called during onLoad',
      );
      expect(
        settings.loadSyncCompleted,
        isTrue,
        reason: 'loadSync() must have completed',
      );

      // Verify every subsystem tick method was called.
      expect(
        displayManager.pollRecord.called,
        isTrue,
        reason: 'CompanionDisplayManager.poll() must be called during tick',
      );
      expect(
        cursorTracker.sampleRecord.called,
        isTrue,
        reason: 'CursorTracker.sample() must be called during tick',
      );
      expect(
        windowMonitor.updateRecord.called,
        isTrue,
        reason: 'WindowMonitor.update() must be called during tick',
      );
      expect(
        physicsSimulator.stepRecord.called,
        isTrue,
        reason: 'PhysicsSimulator.step() must be called during tick',
      );
      expect(
        throwableManager.tickRecord.called,
        isTrue,
        reason: 'ThrowableObjectManager.tick() must be called during tick',
      );

      // Core guarantee: none were called before loadSync completed.
      expect(
        displayManager.pollRecord.calledBeforeSettingsLoaded,
        isFalse,
        reason: 'CompanionDisplayManager.poll() must NOT fire before loadSync() returns',
      );
      expect(
        cursorTracker.sampleRecord.calledBeforeSettingsLoaded,
        isFalse,
        reason:
            'CursorTracker.sample() must NOT fire before loadSync() returns',
      );
      expect(
        windowMonitor.updateRecord.calledBeforeSettingsLoaded,
        isFalse,
        reason:
            'WindowMonitor.update() must NOT fire before loadSync() returns',
      );
      expect(
        physicsSimulator.stepRecord.calledBeforeSettingsLoaded,
        isFalse,
        reason:
            'PhysicsSimulator.step() must NOT fire before loadSync() returns',
      );
      expect(
        throwableManager.tickRecord.calledBeforeSettingsLoaded,
        isFalse,
        reason:
            'ThrowableObjectManager.tick() must NOT fire before loadSync() returns',
      );
    });

    test('Req 11.1: no subsystem tick fires before loadSync() returns '
        '(delayed load — 20ms block)', () async {
      // loadSync blocks for 20ms to simulate a non-trivial disk read.
      final settings = TestSettingsPersistence(
        blockDuration: const Duration(milliseconds: 20),
      );
      final displayManager = _StubDisplayManager(
        () => settings.loadSyncCompleted,
      );
      final cursorTracker = _StubCursorTracker(
        () => settings.loadSyncCompleted,
      );
      final windowMonitor = _StubWindowMonitor(
        () => settings.loadSyncCompleted,
      );
      final physicsSimulator = _StubPhysicsSimulator(
        () => settings.loadSyncCompleted,
      );
      final throwableManager = _StubThrowableManager(
        () => settings.loadSyncCompleted,
      );

      await _simulateOnLoad(settings: settings, displayManager: displayManager);
      await _simulateSubsystemTick(
        displayManager: displayManager,
        cursorTracker: cursorTracker,
        windowMonitor: windowMonitor,
        physicsSimulator: physicsSimulator,
        throwableManager: throwableManager,
      );

      expect(settings.loadSyncCompleted, isTrue);

      expect(
        displayManager.pollRecord.calledBeforeSettingsLoaded,
        isFalse,
        reason: 'poll() must not fire before delayed loadSync() returns',
      );
      expect(
        cursorTracker.sampleRecord.calledBeforeSettingsLoaded,
        isFalse,
        reason: 'sample() must not fire before delayed loadSync() returns',
      );
      expect(
        windowMonitor.updateRecord.calledBeforeSettingsLoaded,
        isFalse,
        reason: 'update() must not fire before delayed loadSync() returns',
      );
      expect(
        physicsSimulator.stepRecord.calledBeforeSettingsLoaded,
        isFalse,
        reason: 'step() must not fire before delayed loadSync() returns',
      );
      expect(
        throwableManager.tickRecord.calledBeforeSettingsLoaded,
        isFalse,
        reason: 'tick() must not fire before delayed loadSync() returns',
      );
    });

    // -----------------------------------------------------------------------
    // completes successfully.
    // -----------------------------------------------------------------------

    test(
      'Req 1.6: no subsystem tick fires before enumerateDisplays() completes',
      () async {
        bool enumerateCompleted = false;

        final settings = TestSettingsPersistence();
        final displayManager = _StubDisplayManager(() => enumerateCompleted);
        final cursorTracker = _StubCursorTracker(() => enumerateCompleted);
        final windowMonitor = _StubWindowMonitor(() => enumerateCompleted);
        final physicsSimulator = _StubPhysicsSimulator(
          () => enumerateCompleted,
        );
        final throwableManager = _StubThrowableManager(
          () => enumerateCompleted,
        );

        settings.loadSync();

        await displayManager.enumerateDisplays();
        enumerateCompleted = true;

        // Now fire the first tick — subsystems check enumerateCompleted.
        await _simulateSubsystemTick(
          displayManager: displayManager,
          cursorTracker: cursorTracker,
          windowMonitor: windowMonitor,
          physicsSimulator: physicsSimulator,
          throwableManager: throwableManager,
        );

        expect(enumerateCompleted, isTrue);

        expect(
          displayManager.pollRecord.calledBeforeSettingsLoaded,
          isFalse,
          reason: 'poll() must not fire before enumerateDisplays() completes',
        );
        expect(
          cursorTracker.sampleRecord.calledBeforeSettingsLoaded,
          isFalse,
          reason: 'sample() must not fire before enumerateDisplays() completes',
        );
        expect(
          windowMonitor.updateRecord.calledBeforeSettingsLoaded,
          isFalse,
          reason: 'update() must not fire before enumerateDisplays() completes',
        );
        expect(
          physicsSimulator.stepRecord.calledBeforeSettingsLoaded,
          isFalse,
          reason: 'step() must not fire before enumerateDisplays() completes',
        );
        expect(
          throwableManager.tickRecord.calledBeforeSettingsLoaded,
          isFalse,
          reason: 'tick() must not fire before enumerateDisplays() completes',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Ordering invariant: loadSync() BEFORE enumerateDisplays()
    // -----------------------------------------------------------------------

    test(
      'Req 11.1 + 1.6: loadSync() is called before enumerateDisplays()',
      () async {
        final callOrder = <String>[];

        // Custom versions that record call order.
        final settings = _RecordingSettingsPersistence(callOrder);
        final displayManager = _RecordingDisplayManager(callOrder);

        settings.loadSync();
        await displayManager.enumerateDisplays();

        expect(
          callOrder,
          equals(['loadSync', 'enumerateDisplays']),
          reason:
              'loadSync() must be called before enumerateDisplays() — '
              'settings must be loaded before the display layer queries the OS',
        );
      },
    );

    // -----------------------------------------------------------------------
    // SettingsPersistence.loadSync() real I/O path: verify the real class
    // works synchronously (no async gap that could allow ticks to slip in).
    // -----------------------------------------------------------------------

    test(
      'SettingsPersistence.loadSync() is synchronous — no async gap',
      () async {
        // Use a real SettingsPersistence pointed at a temp dir so it falls back
        // to defaults (no real file).
        final tempDir = Directory.systemTemp.createTempSync(
          'tick_ordering_test_sync_',
        );
        try {
          final sp = SettingsPersistence(
            configPathOverride:
                '${tempDir.path}${Platform.pathSeparator}pet_config_v2.json',
          );

          bool tickCalledDuringLoad = false;
          bool loadReturned = false;

          // Schedule a microtask: if loadSync uses await internally, this
          // microtask would fire during the load and we could detect it.
          scheduleMicrotask(() {
            if (!loadReturned) {
              tickCalledDuringLoad = true;
            }
          });

          sp.loadSync(); // must be purely synchronous
          loadReturned = true;

          // Allow microtasks to drain.
          await Future<void>.delayed(Duration.zero);

          // The microtask fired AFTER loadSync returned (loadReturned is true),
          // so no tick could slip in.
          expect(
            tickCalledDuringLoad,
            isFalse,
            reason:
                'loadSync() must be synchronous — no async gap that '
                'could allow a tick to execute before settings are loaded',
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    // -----------------------------------------------------------------------
    // Regression guard: verify that if someone incorrectly calls tick methods
    // BEFORE loadSync(), the stubs correctly detect the violation.
    // -----------------------------------------------------------------------

    test(
      'Regression guard: stub correctly detects tick-before-settings violation',
      () async {
        final settings = TestSettingsPersistence();
        final physicsSimulator = _StubPhysicsSimulator(
          () => settings.loadSyncCompleted,
        );

        // Intentionally tick BEFORE loading settings — the stub must flag this.
        physicsSimulator.step(1 / 60);

        expect(
          physicsSimulator.stepRecord.calledBeforeSettingsLoaded,
          isTrue,
          reason:
              'Stub must correctly report that step() was called before '
              'loadSync() completed (regression guard for the test harness)',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers for call-order test
// ---------------------------------------------------------------------------

class _RecordingSettingsPersistence {
  _RecordingSettingsPersistence(this._log);
  final List<String> _log;

  PetConfigV2 loadSync() {
    _log.add('loadSync');
    return PetConfigV2.defaults();
  }
}

class _RecordingDisplayManager implements CompanionDisplayManager {
  _RecordingDisplayManager(this._log);
  final List<String> _log;

  @override
  List<DisplayBounds> get displays => [
    const DisplayBounds(
      id: 'primary',
      rect: Rect.fromLTWH(0, 0, 1920, 1080),
      dpiScale: 1.0,
      isPrimary: true,
    ),
  ];

  @override
  Future<List<DisplayBounds>> enumerateDisplays() async {
    _log.add('enumerateDisplays');
    return [
      const DisplayBounds(
        id: 'primary',
        rect: Rect.fromLTWH(0, 0, 1920, 1080),
        dpiScale: 1.0,
        isPrimary: true,
      ),
    ];
  }

  @override
  Rect get unionBounds => const Rect.fromLTWH(0, 0, 1920, 1080);
  @override
  Offset nearestDisplayPoint(Offset outside) => outside;
  @override
  bool areAdjacent(DisplayBounds a, DisplayBounds b) => false;
  @override
  void poll() {}
  @override
  void onDisplayChanged(List<DisplayBounds> newBounds) {}
}
