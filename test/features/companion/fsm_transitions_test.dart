//
// Tests:
//   - chasing  + throwableStationary → fetching
//   - falling  + landedOnSurface     → idle
//   - reacting + cursorFastMove      → run  (run supersedes reacting)
//   - idle     + surfaceLost         → falling (priority 5 wins)
//   - chasing  + surfaceLost         → falling
//

import 'package:flutter_test/flutter_test.dart';
import 'package:breakmate/features/companion/domain/pet_state_machine.dart';

void main() {
  group('New FSM transitions — Task 3.6', () {
    PetStateMachine makeFsm(PetState startState) {
      final fsm = PetStateMachine();
      fsm.transitionTo(startState);
      expect(
        fsm.currentState,
        equals(startState),
        reason: 'Pre-condition: FSM should start in $startState',
      );
      return fsm;
    }

    // -------------------------------------------------------------------------
    // chasing → throwableStationary → fetching
    // -------------------------------------------------------------------------
    test('From chasing: throwableStationary fires → state becomes fetching '
        '(Req 8.2)', () {
      final fsm = makeFsm(PetState.chasing);
      fsm.handleEvent(PetEvent.throwableStationary);
      expect(
        fsm.currentState,
        equals(PetState.fetching),
        reason:
            'throwableStationary from chasing should transition to fetching',
      );
    });

    // -------------------------------------------------------------------------
    // falling → landedOnSurface → idle
    // -------------------------------------------------------------------------
    test(
      'From falling: landedOnSurface fires → state becomes idle (Req 8.2)',
      () {
        final fsm = makeFsm(PetState.falling);
        fsm.handleEvent(PetEvent.landedOnSurface);
        expect(
          fsm.currentState,
          equals(PetState.idle),
          reason: 'landedOnSurface from falling should transition to idle',
        );
      },
    );

    // -------------------------------------------------------------------------
    // reacting → cursorFastMove → run  (running supersedes reacting, both pri 3
    // but run is the explicit target)
    // -------------------------------------------------------------------------
    test('From reacting: cursorFastMove fires → state becomes run, '
        'run supersedes reacting (Req 5.5, 8.7)', () {
      final fsm = PetStateMachine();
      // Place FSM in reacting by entering from idle via cursorEnteredZone
      fsm.handleEvent(PetEvent.cursorEnteredZone);
      expect(
        fsm.currentState,
        equals(PetState.reacting),
        reason: 'Pre-condition: cursorEnteredZone should put FSM into reacting',
      );

      fsm.handleEvent(PetEvent.cursorFastMove);
      expect(
        fsm.currentState,
        equals(PetState.run),
        reason:
            'cursorFastMove while reacting should transition to run '
            '(run supersedes reacting)',
      );
    });

    // -------------------------------------------------------------------------
    // idle → surfaceLost → falling  (priority 5 wins over all)
    // -------------------------------------------------------------------------
    test('From idle: surfaceLost fires → state becomes falling '
        '(priority 5 wins, Req 8.8)', () {
      final fsm = makeFsm(PetState.idle);
      fsm.handleEvent(PetEvent.surfaceLost);
      expect(
        fsm.currentState,
        equals(PetState.falling),
        reason:
            'surfaceLost from idle should transition to falling (priority 5)',
      );
    });

    // -------------------------------------------------------------------------
    // chasing → surfaceLost → falling  (priority 5 beats chasing priority 4)
    // -------------------------------------------------------------------------
    test('From chasing: surfaceLost fires → state becomes falling '
        '(priority 5 supersedes chasing priority 4, Req 8.8)', () {
      final fsm = makeFsm(PetState.chasing);
      fsm.handleEvent(PetEvent.surfaceLost);
      expect(
        fsm.currentState,
        equals(PetState.falling),
        reason:
            'surfaceLost from chasing should transition to falling; '
            'falling priority (5) > chasing priority (4)',
      );
    });

    // -------------------------------------------------------------------------
    // Additional coverage: fetching → surfaceLost → falling
    // -------------------------------------------------------------------------
    test(
      'From fetching: surfaceLost fires → state becomes falling (Req 8.8)',
      () {
        final fsm = makeFsm(PetState.fetching);
        fsm.handleEvent(PetEvent.surfaceLost);
        expect(
          fsm.currentState,
          equals(PetState.falling),
          reason: 'surfaceLost from fetching should transition to falling',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Verify throwableFetched (disposal/timeout) from chasing → idle
    // -------------------------------------------------------------------------
    test(
      'From chasing: throwableReturned fires → state becomes idle (Req 8.2)',
      () {
        final fsm = makeFsm(PetState.chasing);
        fsm.handleEvent(PetEvent.throwableReturned);
        expect(
          fsm.currentState,
          equals(PetState.idle),
          reason:
              'throwableReturned (throwable disposed/unreachable) from chasing '
              'should return to idle',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Verify throwableReturned from fetching → idle
    // -------------------------------------------------------------------------
    test(
      'From fetching: throwableReturned fires → state becomes idle (Req 8.2)',
      () {
        final fsm = makeFsm(PetState.fetching);
        fsm.handleEvent(PetEvent.throwableReturned);
        expect(
          fsm.currentState,
          equals(PetState.idle),
          reason:
              'throwableReturned from fetching should return to idle after '
              'pet delivers throwable to spawn origin',
        );
      },
    );
  });
}
