import 'dart:ui' show Offset, Rect;

/// Whether the companion's window should receive mouse events right now.
///
/// The window is a transparent rectangle, and a rectangle that accepts the
/// mouse everywhere blocks clicks to whatever is underneath its empty
/// corners. This decides, from where the pointer is, when it is safe to
/// accept them. All rectangles and [cursor] share one screen space.
///
///  * Not draggable/clickable: never.
///  * With a card behind the pet the whole window is the pet, so it accepts
///    everywhere over the window.
///  * Transparent, or in ghost (click-through) mode: only over the pet, or
///    anywhere on the window once the pointer is already interacting with it
///    ([hovered]), so its buttons stay reachable.
bool shouldWindowAcceptMouse({
  required bool draggableClickable,
  required bool clickThrough,
  required bool hasBackdrop,
  required bool hovered,
  required Offset cursor,
  required Rect windowRect,
  required Rect stageRect,
}) {
  if (!draggableClickable) return false;

  // Before the window's place is known there is nothing to test against.
  if (windowRect.isEmpty) return !clickThrough;

  if (!windowRect.deflate(4).contains(cursor)) return false;

  final overPet = !stageRect.isEmpty && stageRect.inflate(28).contains(cursor);
  if (clickThrough) return hovered || overPet;
  if (hasBackdrop) return true;
  return hovered || overPet;
}
