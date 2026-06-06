// Property 14: State transition log completeness
//
// Validates: Requirements 8.9
//
// - transitionLog.length equals the number of actual transitions made
//   (same → same is a no-op and must NOT append an entry)
// - Each entry has non-null previousState, newState, utcTimestamp
// - Timestamps are monotonically non-decreasing

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';

void main() {
  group('Property 14: State transition log completeness', () {
    // A sequence of 11 distinct states to exercise a long chain.
    final elevenDistinctStates = [
      PetState.idle,
      PetState.walk,
      PetState.run,
      PetState.alert,
      PetState.happy,
      PetState.sleep,
      PetState.curious,
      PetState.exploring,
      PetState.chasing,
      PetState.fetching,
      PetState.falling,
    ];

    test('transitionLog length equals number of actual state changes for a '
        'sequence of 10+ distinct states', () {
      final fsm = PetStateMachine();
      var expectedLogCount = 0;
      PetState previous = fsm.currentState; // idle

      for (final state in elevenDistinctStates) {
        fsm.transitionTo(state);
        if (state != previous) {
          expectedLogCount++;
          previous = state;
        }
      }

      expect(
        fsm.transitionLog.length,
        equals(expectedLogCount),
        reason:
            'Log should have exactly $expectedLogCount entries for '
            '${elevenDistinctStates.length} transitionTo() calls',
      );
    });

    test(
      'same → same transitionTo is a no-op and does not append a log entry',
      () {
        final fsm = PetStateMachine();
        fsm.transitionTo(PetState.walk);
        final logLengthBefore = fsm.transitionLog.length;

        // Repeated call with the same state should be ignored.
        fsm.transitionTo(PetState.walk);

        expect(
          fsm.transitionLog.length,
          equals(logLengthBefore),
          reason:
              'Transitioning to the current state must not append a log entry',
        );
      },
    );

    test(
      'every log entry has valid previousState, newState, and UTC utcTimestamp',
      () {
        final fsm = PetStateMachine();
        for (final state in elevenDistinctStates) {
          fsm.transitionTo(state);
        }

        for (final entry in fsm.transitionLog) {
          expect(
            PetState.values.contains(entry.previousState),
            isTrue,
            reason: 'previousState must be a valid PetState',
          );
          expect(
            PetState.values.contains(entry.newState),
            isTrue,
            reason: 'newState must be a valid PetState',
          );
          expect(
            entry.utcTimestamp.isUtc,
            isTrue,
            reason: 'utcTimestamp must be in UTC',
          );
        }
      },
    );

    test('timestamps in transitionLog are monotonically non-decreasing', () {
      final fsm = PetStateMachine();
      for (final state in elevenDistinctStates) {
        fsm.transitionTo(state);
      }

      for (var i = 1; i < fsm.transitionLog.length; i++) {
        final prev = fsm.transitionLog[i - 1].utcTimestamp;
        final curr = fsm.transitionLog[i].utcTimestamp;
        expect(
          curr.isAfter(prev) || curr.isAtSameMomentAs(prev),
          isTrue,
          reason:
              'Log entry $i timestamp $curr must be >= entry ${i - 1} timestamp $prev',
        );
      }
    });

    // -------------------------------------------------------------------------
    // Glados property-based tests
    // -------------------------------------------------------------------------

    /// Validates: Requirements 8.9
    Glados(
      // Generate lists of at least 10 state indices using listWithLengthInRange.
      any.listWithLengthInRange(
        10,
        30,
        any.intInRange(0, PetState.values.length - 1),
      ),
    ).test('log length always matches the number of real state changes in an '
        'arbitrary sequence of transitionTo() calls (≥10 calls)', (
      List<int> stateIndices,
    ) {
      final fsm = PetStateMachine();
      var expectedCount = 0;
      var current = fsm.currentState;

      for (final idx in stateIndices) {
        final next = PetState.values[idx];
        fsm.transitionTo(next);
        if (next != current) {
          expectedCount++;
          current = next;
        }
      }

      expect(
        fsm.transitionLog.length,
        equals(expectedCount),
        reason:
            'Log length ${fsm.transitionLog.length} != '
            'expected $expectedCount',
      );
    });

    /// Validates: Requirements 8.9
    Glados(
      any.listWithLengthInRange(
        10,
        30,
        any.intInRange(0, PetState.values.length - 1),
      ),
    ).test('log timestamps are monotonically non-decreasing for any arbitrary '
        'sequence of transitionTo() calls', (List<int> stateIndices) {
      final fsm = PetStateMachine();
      for (final idx in stateIndices) {
        fsm.transitionTo(PetState.values[idx]);
      }

      for (var i = 1; i < fsm.transitionLog.length; i++) {
        final prev = fsm.transitionLog[i - 1].utcTimestamp;
        final curr = fsm.transitionLog[i].utcTimestamp;
        expect(
          curr.isAfter(prev) || curr.isAtSameMomentAs(prev),
          isTrue,
          reason:
              'Timestamp at index $i ($curr) is before timestamp at '
              'index ${i - 1} ($prev)',
        );
      }
    });

    /// Validates: Requirements 8.9
    Glados(
      any.listWithLengthInRange(
        10,
        30,
        any.intInRange(0, PetState.values.length - 1),
      ),
    ).test(
      'every log entry has valid previousState, newState and UTC timestamp',
      (List<int> stateIndices) {
        final fsm = PetStateMachine();
        for (final idx in stateIndices) {
          fsm.transitionTo(PetState.values[idx]);
        }

        for (final entry in fsm.transitionLog) {
          expect(PetState.values.contains(entry.previousState), isTrue);
          expect(PetState.values.contains(entry.newState), isTrue);
          expect(entry.utcTimestamp.isUtc, isTrue);
          expect(
            entry.previousState,
            isNot(equals(entry.newState)),
            reason:
                'A log entry must never have previousState == newState '
                'because same-state transitions are no-ops',
          );
        }
      },
    );
  });
}
