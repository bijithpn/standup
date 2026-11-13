import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

String breakFormatTime(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final sec = s % 60;
  return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

/// 0..0.6 warmth that ramps up from 18:00 to 21:00 and stays at max overnight; used to shift accents toward amber.
double breakEveningTint(DateTime now) {
  final h = now.hour + now.minute / 60;
  if (h < 6) return 0.6;
  return (((h - 18) / 3).clamp(0.0, 1.0)) * 0.6;
}

Color breakTimeTinted(Color accent, {DateTime? now}) => Color.lerp(
  accent,
  BreakOverlayTheme.amber,
  breakEveningTint(now ?? clock.now()),
)!;

/// True once the countdown has finished or the overlay is already in its completion state.
bool breakIsComplete(BuildContext context, int remaining, int total) =>
    (remaining <= 0 && total > 0) || BreakCompletionScope.isCompleting(context);

double breakProgress(int remaining, int total) =>
    total > 0 ? (1 - remaining / total).clamp(0.0, 1.0) : 0.0;

String breakDurationLabel(int totalSeconds) {
  final mins = totalSeconds ~/ 60;
  final secs = totalSeconds % 60;
  if (mins > 0) return secs > 0 ? '$mins min $secs sec' : '$mins min';
  return '$totalSeconds sec';
}

/// Eye-rest (short) vs recovery (long) label, icon and accent for a break.
class BreakKind {
  final bool isShort;
  final String label;
  final IconData icon;
  final Color accent;

  const BreakKind._(this.isShort, this.label, this.icon, this.accent);

  factory BreakKind.of(BreakModel info) {
    final short = info.type != BreakType.long;
    return short
        ? const BreakKind._(
            true,
            'Eye rest',
            LucideIcons.eye,
            BreakOverlayTheme.eyeRest,
          )
        : const BreakKind._(
            false,
            'Recovery',
            LucideIcons.leaf,
            BreakOverlayTheme.recovery,
          );
  }
}

/// Template accent: the user's per-template override wins, else the custom clock color, else the fallback.
Color breakAccent(
  SettingsModel settings,
  String templateId,
  Color fallback, {
  bool honorClockColor = true,
}) {
  final base = honorClockColor && settings.clockFaceTextColorHex != 0xFFFFFFFF
      ? Color(settings.clockFaceTextColorHex)
      : fallback;
  return BreakOverlayTheme.resolveAccent(
    settings.templateAccentOverrides,
    templateId,
    base,
  );
}

/// Contrast after compositing translucent foregrounds on the actual surface.
double breakContrast(Color foreground, Color background) {
  final fg = Color.alphaBlend(foreground, background).computeLuminance();
  final bg = background.computeLuminance();
  return ((fg > bg ? fg : bg) + 0.05) / ((fg < bg ? fg : bg) + 0.05);
}

/// Preserve custom colors when readable; fall back to the template's ink.
Color breakReadableColor(
  Color color,
  Color background, {
  double minimum = 4.5,
}) {
  if (breakContrast(color, background) >= minimum) return color;
  const light = Color(0xFFE2E5DD);
  const dark = Color(0xFF202521);
  final target =
      breakContrast(light, background) > breakContrast(dark, background)
      ? light
      : dark;
  for (var i = 1; i <= 20; i++) {
    final candidate = Color.lerp(color.withValues(alpha: 1), target, i / 20)!;
    if (breakContrast(candidate, background) >= minimum) return candidate;
  }
  return target;
}

Color breakClockColor(
  SettingsModel settings,
  BreakPalette palette, {
  Color? fallback,
}) {
  final requested = settings.clockFaceTextColorHex != 0xFFFFFFFF
      ? Color(settings.clockFaceTextColorHex)
      : (fallback ?? palette.textPrimary);
  return breakReadableColor(requested, palette.surface);
}

bool breakCanSkip(SettingsModel settings, VoidCallback? onSkip) =>
    !settings.strictMode && onSkip != null;

/// True when animations should be parked (reduced motion or settings preview).
bool breakShouldFreeze(BuildContext context) =>
    BreakMotion.reduced(context) || BreakPreviewScope.isPreview(context);

// Parks looping animations at a still frame when frozen, otherwise (re)starts the loop.
void breakSyncLoop(
  AnimationController c,
  BuildContext context, {
  double park = 0.5,
  bool reverse = false,
}) {
  if (breakShouldFreeze(context)) {
    c.stop();
    c.value = park;
  } else if (!c.isAnimating) {
    c.repeat(reverse: reverse);
  }
}
