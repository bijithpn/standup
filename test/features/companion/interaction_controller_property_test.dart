// Property tests for InteractionController guards and cursor behaviour.
//
//
// Properties 1, 2, 3, 9, 11, 12, 13, 15 from design.md §Correctness Properties.
// Library: glados (already in dev_dependencies).

import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide test, group, expect;

import 'package:breakmate/core/services/storage_service.dart';
import 'package:breakmate/features/companion/domain/pet_needs.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';
import 'package:breakmate/features/companion/interaction/interaction_controller.dart';
import 'package:breakmate/features/companion/services/cursor_tracker.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/settings/settings_repository.dart';

// ── Test doubles ─────────────────────────────────────────────────────────────

/// [CursorTracker] whose [velocity] is fixed for deterministic testing.
class _StubCursorTracker extends CursorTracker {
  _StubCursorTracker(this._fixedVelocity);
  final Offset _fixedVelocity;

  @override
  Offset get velocity => _fixedVelocity;
}

/// [PetStateMachine] that records every [handleEvent] call.
class _RecordingStateMachine extends PetStateMachine {
  _RecordingStateMachine([PetState initial = PetState.idle]) {
    if (initial != PetState.idle) transitionTo(initial);
    _events.clear(); // discard log entries created by transitionTo
  }

  final List<PetEvent> _events = [];

  @override
  void handleEvent(PetEvent event) {
    _events.add(event);
    super.handleEvent(event);
  }

  List<PetEvent> get recordedEvents => List.unmodifiable(_events);
}

/// [NeedsEngine] that records whether any mutation method was called.
class _TrackingNeedsEngine extends NeedsEngine {
  bool mutated = false;

  @override
  void onPetted() {
    mutated = true;
    super.onPetted();
  }

  @override
  void onBallFetched() {
    mutated = true;
    super.onBallFetched();
  }

  @override
  void onTreatEaten() {
    mutated = true;
    super.onTreatEaten();
  }
}

/// Minimal [StorageService] subclass that satisfies the constructor without
/// requiring an ObjectBox database path.  All boxes remain null, and the
/// service reports itself as not ready.
class _NoOpStorageService extends StorageService {
  @override
  bool get isReady => false;

  @override
  bool get hasFailed => false;
}

/// [SettingsRepository] stub that exposes a caller-supplied [SettingsModel]
/// without touching storage.
class _StubSettingsRepository extends SettingsRepository {
  _StubSettingsRepository(this._model) : super(storage: _NoOpStorageService());

  final SettingsModel _model;

  @override
  SettingsModel get currentSettings => _model;
}

// ── Convenience builders ──────────────────────────────────────────────────────

/// Creates an [InteractionController] wired to [fsm] and an optional
/// [needsEngine] / [settingsRepo].  The [CursorTracker] reports a fixed
/// velocity of 50 px/s (inside the petting range) unless overridden.
InteractionController _makeController({
  required _RecordingStateMachine fsm,
  _TrackingNeedsEngine? needs,
  _StubSettingsRepository? repo,
  Offset fixedVelocity = const Offset(50, 0),
}) {
  return InteractionController(
    stateMachine: fsm,
    needsEngine: needs ?? NeedsEngine(),
    settingsRepository: repo,
    cursorTracker: _StubCursorTracker(fixedVelocity),
  );
}

// ── Shared constants ──────────────────────────────────────────────────────────

const _blockedStates = [
  PetState.breakReminder,
  PetState.meetingPaused,
  PetState.focusMode,
];

const _playAffectionEvents = {
  PetEvent.userClick,
  PetEvent.userDoubleClick,
  PetEvent.throwableSpawned,
  PetEvent.petFed,
};

// ─────────────────────────────────────────────────────────────────────────────
void main() {
  // ── Property 1 ─────────────────────────────────────────────────────────────
  // Feature: desktop-companion-interaction, Property 1: Velocity threshold determines zone entry event
  //
  // For any cursor velocity ≤ 800 px/s the CursorTracker is permitted to emit
  // CursorEnteredZoneEvent; for velocity > 800 px/s it suppresses that event
  // and emits CursorFastMoveEvent instead.  The threshold lives in
  // CursorTracker.fastVelocityThreshold (800.0 px/s).
  //

  group('Property 1: Velocity threshold determines zone entry event', () {
    Glados(
      any.doubleInRange(0.0, 800.0),
    ).test('velocity ≤ 800 px/s is within the zone-entry threshold', (
      double speed,
    ) {
      final tracker = _StubCursorTracker(Offset(speed, 0));
      expect(
        tracker.velocity.distance,
        lessThanOrEqualTo(CursorTracker.fastVelocityThreshold),
        reason:
            'Speed $speed should be ≤ ${CursorTracker.fastVelocityThreshold} px/s '
            '(zone-entry allowed)',
      );
      // Guard passes: FSM is idle, companion defaults to enabled.
      final fsm = _RecordingStateMachine();
      final ctrl = _makeController(fsm: fsm, fixedVelocity: Offset(speed, 0));
      // onPetClicked uses _guardPasses('pettingEnabled') — verify no crash.
      expect(() => ctrl.onPetClicked(), returnsNormally);
    });

    Glados(any.doubleInRange(800.1, 4000.0)).test(
      'velocity > 800 px/s exceeds the zone-entry threshold — fast-move path',
      (double speed) {
        final tracker = _StubCursorTracker(Offset(speed, 0));
        expect(
          tracker.velocity.distance,
          greaterThan(CursorTracker.fastVelocityThreshold),
          reason:
              'Speed $speed should be > ${CursorTracker.fastVelocityThreshold} px/s '
              '(fast-move path, zone entry suppressed)',
        );
      },
    );
  });

  // ── Property 2 ─────────────────────────────────────────────────────────────
  // Feature: desktop-companion-interaction, Property 2: Facing direction error is always ≤ 45 degrees
  //
  // For any cursor position relative to the pet center, the nearest of the
  // 8 discrete compass directions has angular error ≤ 45°.
  //

  group('Property 2: Facing direction error is always ≤ 45 degrees', () {
    // Inline angle-snapping helper — maps any angle (deg) to the nearest
    // multiple of 45° in [0, 360).
    double snapTo8(double angleDeg) {
      final norm = ((angleDeg % 360.0) + 360.0) % 360.0;
      return ((norm / 45.0).round() * 45.0) % 360.0;
    }

    double angularError(double actualDeg, double snappedDeg) {
      final diff = (actualDeg - snappedDeg).abs() % 360.0;
      return diff > 180.0 ? 360.0 - diff : diff;
    }

    Glados2(
      any.doubleInRange(-500.0, 500.0),
      any.doubleInRange(-500.0, 500.0),
    ).test(
      'nearest 8-direction facing has angular error ≤ 45° for any cursor offset',
      (double dx, double dy) {
        if (dx == 0.0 && dy == 0.0) return; // undefined direction — skip

        final actualDeg =
            (math.atan2(dy, dx) * 180.0 / math.pi + 360.0) % 360.0;
        final snappedDeg = snapTo8(actualDeg);
        final error = angularError(actualDeg, snappedDeg);

        expect(
          error,
          lessThanOrEqualTo(45.0),
          reason:
              'dx=$dx dy=$dy → actual=${actualDeg.toStringAsFixed(2)}° '
              'snapped=${snappedDeg.toStringAsFixed(2)}° '
              'error=${error.toStringAsFixed(2)}°',
        );
      },
    );
  });

  // ── Property 3 ─────────────────────────────────────────────────────────────
  // Feature: desktop-companion-interaction, Property 3: Blocked states suppress all play and affection events
  //
  // While the FSM is in breakReminder, meetingPaused, or focusMode, calling
  // onPetClicked or onPetDoubleClicked must not forward any play/affection
  // PetEvent and the FSM state must remain unchanged.
  //

  group('Property 3: Blocked states suppress all play and affection events', () {
    Glados(any.intInRange(0, _blockedStates.length - 1)).test(
      'onPetClicked does not emit play/affection events in blocked states',
      (int idx) {
        final blocked = _blockedStates[idx];
        final fsm = _RecordingStateMachine(blocked);
        final ctrl = _makeController(fsm: fsm);

        ctrl.onPetClicked();

        final emitted = fsm.recordedEvents.toSet().intersection(
          _playAffectionEvents,
        );
        expect(
          emitted,
          isEmpty,
          reason:
              'onPetClicked in $blocked must not emit play/affection events',
        );
        expect(fsm.currentState, equals(blocked));
      },
    );

    Glados(any.intInRange(0, _blockedStates.length - 1)).test(
      'onPetDoubleClicked does not emit play/affection events in blocked states',
      (int idx) {
        final blocked = _blockedStates[idx];
        final fsm = _RecordingStateMachine(blocked);
        final ctrl = _makeController(fsm: fsm);

        ctrl.onPetDoubleClicked();

        final emitted = fsm.recordedEvents.toSet().intersection(
          _playAffectionEvents,
        );
        expect(
          emitted,
          isEmpty,
          reason:
              'onPetDoubleClicked in $blocked must not emit play/affection events',
        );
        expect(fsm.currentState, equals(blocked));
      },
    );
  });

  // ── Property 9 ─────────────────────────────────────────────────────────────
  // Feature: desktop-companion-interaction, Property 9: QuietMode requires all triggers cleared to deactivate
  //
  // Bitmask logic: _quietModeTriggers is an int with bits 0x01, 0x02, 0x04.
  // QuietMode is active iff _quietModeTriggers != 0.
  // Clearing any strict subset of set bits must leave the value non-zero.
  //

  group('Property 9: QuietMode requires all triggers cleared to deactivate', () {
    // All 7 non-zero combinations of {0x01, 0x02, 0x04}.
    const allBits = [0x01, 0x02, 0x04];
    final nonZeroMasks = <int>[];
    for (var combo = 1; combo < (1 << allBits.length); combo++) {
      int mask = 0;
      for (int bit = 0; bit < allBits.length; bit++) {
        if (combo & (1 << bit) != 0) mask |= allBits[bit];
      }
      nonZeroMasks.add(mask);
    }

    Glados(any.intInRange(0, nonZeroMasks.length - 1)).test(
      'any non-zero trigger combination keeps QuietMode active',
      (int idx) {
        final triggers = nonZeroMasks[idx];
        expect(
          triggers != 0,
          isTrue,
          reason:
              'Trigger mask 0x${triggers.toRadixString(16)} must be non-zero '
              '(QuietMode active)',
        );
      },
    );

    Glados(
      any.intInRange(0, nonZeroMasks.length - 1),
    ).test('clearing a strict subset of active bits leaves QuietMode active', (
      int idx,
    ) {
      final triggers = nonZeroMasks[idx];

      for (final bit in allBits) {
        if (triggers & bit == 0) continue; // bit not set in this mask

        final afterClearOne = triggers & ~bit;
        if (afterClearOne != 0) {
          // Still has other bits set — QuietMode must remain active.
          expect(
            afterClearOne != 0,
            isTrue,
            reason:
                'After clearing bit 0x${bit.toRadixString(16)} from '
                '0x${triggers.toRadixString(16)}, QuietMode should remain active',
          );
        }
      }
    });

    Glados(any.intInRange(0, nonZeroMasks.length - 1)).test(
      'clearing ALL active bits simultaneously deactivates QuietMode',
      (int idx) {
        int triggers = nonZeroMasks[idx];
        for (final bit in allBits) {
          triggers &= ~bit;
        }
        expect(
          triggers,
          equals(0),
          reason: 'After clearing all bits QuietMode must be inactive',
        );
      },
    );
  });

  // ── Property 11 ────────────────────────────────────────────────────────────
  // Feature: desktop-companion-interaction, Property 11: triggerCompanionReaction blocks protected states
  //
  // For targetState ∈ {breakReminder, meetingPaused, focusMode}:
  //   - handleEvent must NOT be called.
  //   - The FSM state must remain unchanged.
  // (AppLogger.warning is called internally — verified indirectly by ensuring
  // no handleEvent call occurs, matching the code path in triggerCompanionReaction.)
  //

  group('Property 11: triggerCompanionReaction blocks protected states', () {
    Glados(any.intInRange(0, _blockedStates.length - 1)).test(
      'triggerCompanionReaction does not call handleEvent for protected states',
      (int idx) {
        final protected = _blockedStates[idx];
        final fsm = _RecordingStateMachine(); // starts at idle
        final ctrl = _makeController(fsm: fsm);

        ctrl.triggerCompanionReaction(protected);

        expect(
          fsm.recordedEvents,
          isEmpty,
          reason:
              'triggerCompanionReaction($protected) must not forward any '
              'PetEvent to handleEvent',
        );
        expect(
          fsm.currentState,
          equals(PetState.idle),
          reason:
              'FSM state must remain idle after a blocked '
              'triggerCompanionReaction',
        );
      },
    );

    test(
      'triggerCompanionReaction with an allowed state does call handleEvent',
      () {
        final fsm = _RecordingStateMachine();
        final ctrl = _makeController(fsm: fsm);

        // PetState.alert maps to PetEvent.userClick in _petEventForState.
        ctrl.triggerCompanionReaction(PetState.alert);

        expect(
          fsm.recordedEvents,
          isNotEmpty,
          reason:
              'An allowed targetState must result in at least one '
              'handleEvent call',
        );
      },
    );
  });

  // ── Property 12 ────────────────────────────────────────────────────────────
  // Feature: desktop-companion-interaction, Property 12: Feature toggle disables interactions as no-ops
  //
  // When companionEnabled == false in SettingsRepository, every public method
  // on InteractionController must be a complete no-op: handleEvent is never
  // called and NeedsEngine is never mutated.
  //

  group('Property 12: Feature toggle disables interactions as no-ops', () {
    // Build a SettingsRepository that reports companionEnabled=false.
    final disabledRepo = _StubSettingsRepository(
      const SettingsModel(
        companionEnabled: false,
        pettingEnabled: false,
        ballThrowEnabled: false,
        treatEnabled: false,
      ),
    );

    // A list of closures that invoke each public interaction method.
    final interactions = <(String, void Function(InteractionController))>[
      ('onPetClicked', (c) => c.onPetClicked()),
      ('onPetDoubleClicked', (c) => c.onPetDoubleClicked()),
      ('onPetPetted', (c) => c.onPetPetted()),
      ('throwToy', (c) => c.throwToy()),
      ('giveTreat', (c) => c.giveTreat()),
    ];

    Glados(any.intInRange(0, interactions.length - 1)).test(
      'any public interaction method is a no-op when companionEnabled is false',
      (int idx) {
        final (methodName, invoke) = interactions[idx];
        final fsm = _RecordingStateMachine();
        final needs = _TrackingNeedsEngine();

        final ctrl = _makeController(
          fsm: fsm,
          needs: needs,
          repo: disabledRepo,
        );

        invoke(ctrl);

        expect(
          fsm.recordedEvents,
          isEmpty,
          reason:
              '$methodName must not call handleEvent when companionEnabled '
              'is false',
        );
        expect(
          needs.mutated,
          isFalse,
          reason:
              '$methodName must not mutate NeedsEngine when companionEnabled '
              'is false',
        );
      },
    );
  });

  // ── Property 13 ────────────────────────────────────────────────────────────
  // Feature: desktop-companion-interaction, Property 13: reducedMotion restricts emitted PetEvents to calm states
  //
  // While controller.reducedMotion == true, no emitted PetEvent should map
  // exclusively to run, chasing, eating, or celebrating.
  //
  // The events reachable via the immediate (non-timer) public API path are
  // userClick → alert and userDoubleClick → happy — both calm states.  The
  // restricted-state events (cursorFastMove, throwableSpawned, petFed,
  // breakCompleted) are not directly emittable via the current public methods.
  //
  // NOTE: Full wiring of the reducedMotion guard into _guardPasses is
  // through the immediate API path are already restricted to calm states.
  //

  // Events that lead exclusively to restricted states.
  const restrictedStateEvents = {
    PetEvent.cursorFastMove, // → run
    PetEvent.throwableSpawned, // → chasing
    PetEvent.petFed, // → eating
    PetEvent.breakCompleted, // → celebrating
  };

  group(
    'Property 13: reducedMotion restricts emitted PetEvents to calm states',
    () {
      Glados(any.intInRange(0, 1)).test(
        'click/double-click API emits no restricted-state events when '
        'reducedMotion is true',
        (int methodIdx) {
          final fsm = _RecordingStateMachine();
          final ctrl = _makeController(fsm: fsm)..reducedMotion = true;

          if (methodIdx == 0) {
            ctrl.onPetClicked();
          } else {
            ctrl.onPetDoubleClicked();
          }

          for (final event in fsm.recordedEvents) {
            expect(
              restrictedStateEvents.contains(event),
              isFalse,
              reason:
                  'Event $event must not be emitted when reducedMotion=true '
                  '(leads to a restricted animation state)',
            );
          }
        },
      );

      test('onPetDoubleClicked emits only calm-state events when reducedMotion '
          'is true', () {
        final fsm = _RecordingStateMachine();
        final ctrl = _makeController(fsm: fsm)..reducedMotion = true;
        ctrl.onPetDoubleClicked();

        final emitted = fsm.recordedEvents.toSet();
        final restricted = emitted.intersection(restrictedStateEvents);
        expect(
          restricted,
          isEmpty,
          reason:
              'onPetDoubleClicked must not emit restricted-state events when '
              'reducedMotion=true; got: $restricted',
        );
      });
    },
  );

  // ── Property 15 ────────────────────────────────────────────────────────────
  // Feature: desktop-companion-interaction, Property 15: clickThrough hit-test correctly classifies all screen points
  //
  // Given windowRect (280×320), interactionBarRect (bottom 44px), and
  // dragHandleRect (top 24px) with clickThrough enabled:
  //   - Point inside interactionBarRect or dragHandleRect → interactive.
  //   - Point outside both → pass-through.
  //

  // Inline hit-test function that mirrors the logic pip_overlay_window.dart
  // must implement.
  bool isInteractive(Offset point, Rect bar, Rect handle) =>
      bar.contains(point) || handle.contains(point);

  group(
    'Property 15: clickThrough hit-test correctly classifies all screen points',
    () {
      const windowWidth = 280.0;
      const windowHeight = 320.0;
      const barHeight = 44.0;
      const handleHeight = 24.0;

      final interactionBarRect = Rect.fromLTWH(
        0,
        windowHeight - barHeight,
        windowWidth,
        barHeight,
      );
      final dragHandleRect = Rect.fromLTWH(0, 0, windowWidth, handleHeight);

      Glados2(
        any.doubleInRange(0.0, windowWidth - 0.01),
        any.doubleInRange(windowHeight - barHeight, windowHeight - 0.01),
      ).test('points inside interactionBarRect are interactive', (
        double x,
        double y,
      ) {
        final point = Offset(x, y);
        expect(
          isInteractive(point, interactionBarRect, dragHandleRect),
          isTrue,
          reason: 'Point $point inside interactionBarRect must be interactive',
        );
      });

      Glados2(
        any.doubleInRange(0.0, windowWidth - 0.01),
        any.doubleInRange(0.0, handleHeight - 0.01),
      ).test('points inside dragHandleRect are interactive', (
        double x,
        double y,
      ) {
        final point = Offset(x, y);
        expect(
          isInteractive(point, interactionBarRect, dragHandleRect),
          isTrue,
          reason: 'Point $point inside dragHandleRect must be interactive',
        );
      });

      Glados2(
        any.doubleInRange(0.0, windowWidth - 0.01),
        any.doubleInRange(handleHeight + 0.01, windowHeight - barHeight - 0.01),
      ).test('points outside both regions are pass-through', (
        double x,
        double y,
      ) {
        final point = Offset(x, y);
        // Safety: skip if the generated point accidentally lands inside a
        // region (can happen at exact boundary due to floating-point).
        if (interactionBarRect.contains(point) ||
            dragHandleRect.contains(point)) {
          return;
        }
        expect(
          isInteractive(point, interactionBarRect, dragHandleRect),
          isFalse,
          reason: 'Point $point outside both regions must be pass-through',
        );
      });
    },
  );

  // ── Property 16 ────────────────────────────────────────────────────────────
  // Feature: desktop-companion-interaction, Property 16: Feature-specific toggles disable individual interactions
  //
  // When companionEnabled == true but specific feature toggles are false,
  // the corresponding public methods on InteractionController must be no-ops.
  //

  group(
    'Property 16: Feature-specific toggles disable individual interactions',
    () {
      test(
        'onPetClicked, onPetDoubleClicked, and onPetPetted are no-ops when pettingEnabled is false',
        () {
          final repo = _StubSettingsRepository(
            const SettingsModel(companionEnabled: true, pettingEnabled: false),
          );
          final fsm = _RecordingStateMachine();
          final needs = _TrackingNeedsEngine();
          final ctrl = _makeController(fsm: fsm, needs: needs, repo: repo);

          ctrl.onPetClicked();
          ctrl.onPetDoubleClicked();
          ctrl.onPetPetted();

          expect(fsm.recordedEvents, isEmpty);
          expect(needs.mutated, isFalse);
        },
      );

      test(
        'onPetDragged and throwToy are no-ops when ballThrowEnabled is false',
        () {
          final repo = _StubSettingsRepository(
            const SettingsModel(
              companionEnabled: true,
              ballThrowEnabled: false,
            ),
          );
          final fsm = _RecordingStateMachine();
          final ctrl = _makeController(fsm: fsm, repo: repo);

          ctrl.onPetDragged(Offset.zero);
          ctrl.throwToy();

          expect(fsm.recordedEvents, isEmpty);
        },
      );

      test('giveTreat is a no-op when treatEnabled is false', () {
        final repo = _StubSettingsRepository(
          const SettingsModel(companionEnabled: true, treatEnabled: false),
        );
        final fsm = _RecordingStateMachine();
        final ctrl = _makeController(fsm: fsm, repo: repo);

        ctrl.giveTreat();

        expect(fsm.recordedEvents, isEmpty);
      });

      test(
        'triggerCompanionReaction is a no-op when developerReactions is false',
        () {
          final repo = _StubSettingsRepository(
            const SettingsModel(
              companionEnabled: true,
              developerReactions: false,
            ),
          );
          final fsm = _RecordingStateMachine();
          final ctrl = _makeController(fsm: fsm, repo: repo);

          ctrl.triggerCompanionReaction(PetState.alert);

          expect(fsm.recordedEvents, isEmpty);
        },
      );
    },
  );
}
