// Property 13: Exactly one active state invariant
//
// Validates: Requirements 8.1
//
// For every PetEvent value applied to a fresh PetStateMachine, assert
// currentState is a valid PetState enum value after each event.
// Covers all starting-state × event combinations.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';

void main() {
  group('Property 13: Exactly one active state invariant', () {
    /// Helper: set of all valid PetState values.
    final allStates = PetState.values.toSet();

    /// Helper: all PetEvent values.
    final allEvents = PetEvent.values;

    test(
        'currentState is always a valid PetState after applying any single event '
        'to a fresh FSM (all events)', () {
      for (final event in allEvents) {
        final fsm = PetStateMachine();
        fsm.handleEvent(event);
        expect(
          allStates.contains(fsm.currentState),
          isTrue,
          reason:
              'After firing $event on a fresh FSM the state '
              '"${fsm.currentState}" must be a valid PetState',
        );
      }
    });

    test(
        'currentState is always a valid PetState for every starting-state × '
        'event combination', () {
      for (final startState in PetState.values) {
        for (final event in allEvents) {
          final fsm = PetStateMachine();
          fsm.transitionTo(startState);
          fsm.handleEvent(event);

          expect(
            allStates.contains(fsm.currentState),
            isTrue,
            reason:
                'After firing $event from state $startState the resulting '
                'state "${fsm.currentState}" must be a valid PetState',
          );
        }
      }
    });

    // -------------------------------------------------------------------------
    // Glados property-based test: random sequences of events on a fresh FSM
    // -------------------------------------------------------------------------

    /// Validates: Requirements 8.1
    Glados(any.list(any.intInRange(0, PetEvent.values.length - 1))).test(
      'currentState remains a valid PetState after every event in an '
      'arbitrary sequence applied to a fresh FSM',
      (List<int> eventIndices) {
        final fsm = PetStateMachine();
        for (final idx in eventIndices) {
          final event = PetEvent.values[idx];
          fsm.handleEvent(event);
          expect(
            allStates.contains(fsm.currentState),
            isTrue,
            reason:
                'After firing $event the state "${fsm.currentState}" must '
                'be a valid PetState',
          );
        }
      },
    );

    /// Validates: Requirements 8.1
    Glados2(
      any.intInRange(0, PetState.values.length - 1),
      any.intInRange(0, PetEvent.values.length - 1),
    ).test(
      'currentState is a valid PetState for every (startState, event) pair',
      (int stateIdx, int eventIdx) {
        final startState = PetState.values[stateIdx];
        final event = PetEvent.values[eventIdx];

        final fsm = PetStateMachine();
        fsm.transitionTo(startState);
        fsm.handleEvent(event);

        expect(
          allStates.contains(fsm.currentState),
          isTrue,
          reason:
              'After firing $event from $startState the state '
              '"${fsm.currentState}" must be a valid PetState',
        );
      },
    );
  });
}
