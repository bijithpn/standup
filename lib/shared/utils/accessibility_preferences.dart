import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:breakmate/features/settings/settings_model.dart';

/// Multiplies the system text scale rather than replacing it with an app default.
MediaQueryData accessibleMediaData(
  MediaQueryData media,
  SettingsModel settings, {
  double legacyLargeScale = 1.15,
}) => media.copyWith(
  textScaler: TextScaler.linear(
    media.textScaler.scale(1) *
        math.max(
          settings.experience.textScale,
          settings.largeOverlayText ? legacyLargeScale : 1,
        ),
  ),
  highContrast: media.highContrast || settings.experience.highContrast,
  disableAnimations:
      media.disableAnimations ||
      settings.reduceMotion ||
      !settings.enableAnimations,
);
