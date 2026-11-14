import 'dart:ui' show Offset, Rect;

/// Decides whether the always-on-top PiP window should capture mouse events or let them click through to apps below.
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

  if (windowRect.isEmpty) return !clickThrough;

  if (!windowRect.deflate(4).contains(cursor)) return false;

  final overPet = !stageRect.isEmpty && stageRect.inflate(28).contains(cursor);
  if (clickThrough) return hovered || overPet;
  if (hasBackdrop) return true;
  return hovered || overPet;
}
