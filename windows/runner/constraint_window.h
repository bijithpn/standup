#ifndef RUNNER_CONSTRAINT_WINDOW_H_
#define RUNNER_CONSTRAINT_WINDOW_H_

#include <flutter/flutter_engine.h>

// Constrained Mode zone: a resizable, always-on-top frame with a transparent,
// click-through interior. Positions and sizes are in DIPs with a top-left
// origin, the same space getCursorPosition / getVisibleWindows report.
void RegisterConstraintWindowBridge(flutter::FlutterEngine* engine);
void ShowConstraintWindow(double x, double y, double width, double height);
void HideConstraintWindow();

#endif  // RUNNER_CONSTRAINT_WINDOW_H_
