// Property 6: Prior-state restoration on zone exit
//
//
// For each PetState value (excluding `reacting`):
//   1. Create fresh FSM
//   2. Force into that starting state via transitionTo()
//   3. Trigger reacting via transitionTo (guarantees _priorState is set)
//   4. Fire cursorExitedZone
//   5. Assert resulting state == original starting state

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';

void main() {
  group('Property 6: Prior-state restoration on zone exit', () {
    // States that can be the "prior" state before entering reacting.
    // We exclude reacting itself (same-state is a no-op in _transitionTo).
    final testableStates = PetState.values
        .where((s) => s != PetState.reacting)
        .toList();

    test('cursorExitedZone restores the prior state for every non-reacting '
        'starting state (exhaustive)', () {
      for (final startState in testableStates) {
        final fsm = PetStateMachine();

        // Step 2 – force the FSM into startState
        fsm.transitionTo(startState);

        // Step 3 – enter reacting (records _priorState = startState)
        fsm.transitionTo(PetState.reacting);
        expect(
          fsm.currentState,
          equals(PetState.reacting),
          reason: 'Pre-condition: FSM should be in reacting',
        );

        // Step 4 – fire cursorExitedZone
        fsm.handleEvent(PetEvent.cursorExitedZone);

        // Step 5 – assert restored state
        expect(
          fsm.currentState,
          equals(startState),
          reason: 'After cursorExitedZone the FSM should restore "$startState"',
        );
      }
    });

    test('windowOverlapEnded also restores the prior state for every '
        'non-reacting starting state (exhaustive)', () {
      for (final startState in testableStates) {
        final fsm = PetStateMachine();
        fsm.transitionTo(startState);
        fsm.transitionTo(PetState.reacting);
        fsm.handleEvent(PetEvent.windowOverlapEnded);

        expect(
          fsm.currentState,
          equals(startState),
          reason:
              'After windowOverlapEnded the FSM should restore "$startState"',
        );
      }
    });

    test('restoration falls back to idle when the FSM starts at idle before '
        'entering reacting (fresh FSM default)', () {
      // A fresh FSM starts at idle; transitionTo(reacting) sets _priorState=idle.
      final fsm = PetStateMachine();
      fsm.transitionTo(PetState.reacting);
      fsm.handleEvent(PetEvent.cursorExitedZone);

      expect(fsm.currentState, equals(PetState.idle));
    });

    // -------------------------------------------------------------------------
    // Glados property-based tests
    // -------------------------------------------------------------------------

    Glados(any.intInRange(0, testableStates.length - 1)).test(
      'cursorExitedZone always restores the prior non-reacting state',
      (int idx) {
        final startState = testableStates[idx];
        final fsm = PetStateMachine();

        fsm.transitionTo(startState);
        fsm.transitionTo(PetState.reacting);
        fsm.handleEvent(PetEvent.cursorExitedZone);

        expect(
          fsm.currentState,
          equals(startState),
          reason: 'Expected restoration to $startState after cursorExitedZone',
        );
      },
    );

    Glados(any.intInRange(0, testableStates.length - 1)).test(
      'windowOverlapEnded always restores the prior non-reacting state',
      (int idx) {
        final startState = testableStates[idx];
        final fsm = PetStateMachine();

        fsm.transitionTo(startState);
        fsm.transitionTo(PetState.reacting);
        fsm.handleEvent(PetEvent.windowOverlapEnded);

        expect(
          fsm.currentState,
          equals(startState),
          reason:
              'Expected restoration to $startState after windowOverlapEnded',
        );
      },
    );
  });
}
