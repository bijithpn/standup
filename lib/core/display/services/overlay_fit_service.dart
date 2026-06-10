import 'package:flutter/material.dart';
import 'package:breakmate/core/display/models/display_info.dart';
import 'package:breakmate/core/display/models/overlay_display_config.dart';

class OverlayFitService {
  Rect calculateBounds(DisplayInfo display, OverlayDisplayConfig config) {
    if (config.ignoreSafeAreas) {
      return Rect.fromLTWH(0, 0, display.bounds.width, display.bounds.height);
    } else {
      return Rect.fromLTWH(
        0,
        0,
        display.workArea.width,
        display.workArea.height,
      );
    }
  }

  /// Adaptive fit for rendering background images/videos to avoid stretching
  Rect calculateAdaptiveContentRect(
    Size contentSize,
    Size targetSize,
    OverlayFitMode mode,
  ) {
    if (contentSize.width == 0 || contentSize.height == 0) {
      return Rect.fromLTWH(0, 0, targetSize.width, targetSize.height);
    }

    double contentAspect = contentSize.width / contentSize.height;
    double targetAspect = targetSize.width / targetSize.height;

    switch (mode) {
      case OverlayFitMode.contain:
        if (contentAspect > targetAspect) {
          double height = targetSize.width / contentAspect;
          return Rect.fromLTWH(
            0,
            (targetSize.height - height) / 2,
            targetSize.width,
            height,
          );
        } else {
          double width = targetSize.height * contentAspect;
          return Rect.fromLTWH(
            (targetSize.width - width) / 2,
            0,
            width,
            targetSize.height,
          );
        }
      case OverlayFitMode.cover:
      case OverlayFitMode.adaptive:
        if (contentAspect > targetAspect) {
          double width = targetSize.height * contentAspect;
          return Rect.fromLTWH(
            (targetSize.width - width) / 2,
            0,
            width,
            targetSize.height,
          );
        } else {
          double height = targetSize.width / contentAspect;
          return Rect.fromLTWH(
            0,
            (targetSize.height - height) / 2,
            targetSize.width,
            height,
          );
        }
      case OverlayFitMode.fill:
        return Rect.fromLTWH(0, 0, targetSize.width, targetSize.height);
    }
  }
}
