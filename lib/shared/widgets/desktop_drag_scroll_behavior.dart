import 'dart:ui';
import 'package:flutter/material.dart';

/// Custom ScrollBehavior that allows scrolling by dragging with mouse,
/// touch, or trackpad on all desktop platforms.
class DesktopDragScrollBehavior extends MaterialScrollBehavior {
  const DesktopDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
