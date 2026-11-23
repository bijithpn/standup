import 'dart:math' as math;

import 'package:breakmate/features/themes/domain/app_theme_preset.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  tearDown(() => AppTheme.applyPreset(AppThemePreset.nordicSlate));

  for (final preset in AppThemePreset.allPresets) {
    test('${preset.id} meets contrast targets', () {
      AppTheme.applyPreset(preset);
      final surfaces = {
        'surface': AppTheme.surface,
        'surfaceCard': AppTheme.surfaceCard,
        'surfaceElevated': AppTheme.surfaceElevated,
      };
      void atLeast(String label, Color fg, Color bg, double min) {
        expect(
          contrast(fg, bg),
          greaterThanOrEqualTo(min),
          reason: '${preset.id} $label',
        );
      }

      surfaces.forEach((name, bg) {
        atLeast('textPrimary on $name', AppTheme.textPrimary, bg, 7);
        atLeast('textSecondary on $name', AppTheme.textSecondary, bg, 4.5);
        atLeast('textMuted on $name', AppTheme.textMuted, bg, 4.5);
      });
      final surface = AppTheme.surface;
      atLeast('onAccent on accent', AppTheme.onAccent, AppTheme.accent, 4.5);
      atLeast('accent on surface', AppTheme.accent, surface, 3);
      atLeast('success', AppTheme.success, surface, 3);
      atLeast('warning', AppTheme.warning, surface, 3);
      atLeast('error', AppTheme.error, surface, 3);
      atLeast('info', AppTheme.info, surface, 3);
      atLeast('shortBreak', AppTheme.shortBreak, surface, 3);
      atLeast('longBreak', AppTheme.longBreak, surface, 3);
      atLeast('border', AppTheme.border, surface, 2);
      atLeast('borderSubtle', AppTheme.borderSubtle, surface, 1.5);
    });
  }
}
