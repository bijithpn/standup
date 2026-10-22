import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:breakmate/features/companion/overlay/mouse_hit_policy.dart';

// A 280x320 window on a second monitor placed left of and above the primary.
const Rect _window = Rect.fromLTWH(-1500, -900, 280, 320);
const Rect _stage = Rect.fromLTWH(-1480, -820, 240, 240);

bool _accepts({
  bool draggable = true,
  bool clickThrough = false,
  bool backdrop = false,
  bool hovered = false,
  Offset cursor = const Offset(-1360, -700),
  Rect window = _window,
  Rect stage = _stage,
}) => shouldWindowAcceptMouse(
  draggableClickable: draggable,
  clickThrough: clickThrough,
  hasBackdrop: backdrop,
  hovered: hovered,
  cursor: cursor,
  windowRect: window,
  stageRect: stage,
);

void main() {
  group('transparent window', () {
    test('accepts the mouse over the pet', () {
      expect(_accepts(cursor: _stage.center), isTrue);
    });

    test('lets clicks through in the transparent margins', () {
      // Inside the window, outside the pet's square.
      expect(_accepts(cursor: const Offset(-1495, -895)), isFalse);
      expect(_accepts(cursor: const Offset(-1225, -590)), isFalse);
    });

    test('keeps the whole window once the pointer is interacting', () {
      expect(
        _accepts(hovered: true, cursor: const Offset(-1495, -895)),
        isTrue,
      );
    });

    test('lets clicks through outside the window altogether', () {
      expect(_accepts(hovered: true, cursor: const Offset(0, 0)), isFalse);
    });
  });

  group('window with a card behind the pet', () {
    test('accepts anywhere over the window', () {
      expect(
        _accepts(backdrop: true, cursor: const Offset(-1495, -895)),
        isTrue,
      );
    });

    test('still lets clicks through outside it', () {
      expect(_accepts(backdrop: true, cursor: const Offset(100, 100)), isFalse);
    });
  });

  group('ghost mode', () {
    test('ignores the mouse away from the pet', () {
      expect(
        _accepts(
          clickThrough: true,
          backdrop: true,
          cursor: const Offset(-1495, -895),
        ),
        isFalse,
      );
    });

    test('still allows the pet to be reached', () {
      expect(_accepts(clickThrough: true, cursor: _stage.center), isTrue);
    });
  });

  group('not draggable/clickable', () {
    test('never accepts', () {
      expect(_accepts(draggable: false, cursor: _stage.center), isFalse);
      expect(
        _accepts(draggable: false, backdrop: true, hovered: true),
        isFalse,
      );
    });
  });

  group('before the window is placed', () {
    test('accepts unless in ghost mode', () {
      expect(_accepts(window: Rect.zero), isTrue);
      expect(_accepts(window: Rect.zero, clickThrough: true), isFalse);
    });

    test('an unknown pet area never claims the mouse by accident', () {
      expect(_accepts(stage: Rect.zero, cursor: _window.center), isFalse);
    });
  });
}
