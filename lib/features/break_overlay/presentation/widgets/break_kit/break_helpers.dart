import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

/// `MM:SS`, zero padded.
String breakFormatTime(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final sec = s % 60;
  return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

/// 0 before 18:00, ramping to 0.6 by 21:00, held until 06:00, then gone.
double breakEveningTint(DateTime now) {
  final h = now.hour + now.minute / 60;
  if (h < 6) return 0.6;
  return (((h - 18) / 3).clamp(0.0, 1.0)) * 0.6;
}

/// [accent] warmed toward amber in the evening, so late breaks do not glare
/// blue. Unchanged during the day.
Color breakTimeTinted(Color accent, {DateTime? now}) => Color.lerp(
  accent,
  BreakOverlayTheme.amber,
  breakEveningTint(now ?? clock.now()),
)!;

/// Elapsed fraction of the break, 0..1.
double breakProgress(int remaining, int total) =>
    total > 0 ? (1 - remaining / total).clamp(0.0, 1.0) : 0.0;

/// Human duration such as `1 min 30 sec`, `45 sec`.
String breakDurationLabel(int totalSeconds) {
  final mins = totalSeconds ~/ 60;
  final secs = totalSeconds % 60;
  if (mins > 0) return secs > 0 ? '$mins min $secs sec' : '$mins min';
  return '$totalSeconds sec';
}

/// Short vs long break presentation: label, icon and default accent.
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

/// Accent for [templateId]: the user's per-template pin wins, then the
/// legacy "clock color" setting when it was changed from white, then
/// [fallback].
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

/// Countdown color: the user's clock color when customised, otherwise the
/// palette's primary text so light themes stay legible.
Color breakClockColor(
  SettingsModel settings,
  BreakPalette palette, {
  Color? fallback,
}) => settings.clockFaceTextColorHex != 0xFFFFFFFF
    ? Color(settings.clockFaceTextColorHex)
    : (fallback ?? palette.textPrimary);

/// Whether the skip affordance should be offered at all.
bool breakCanSkip(SettingsModel settings, VoidCallback? onSkip) =>
    !settings.strictMode && onSkip != null;

/// Whether decorative loops should be parked on a static frame: reduced
/// motion or a gallery thumbnail.
bool breakShouldFreeze(BuildContext context) =>
    BreakMotion.reduced(context) || BreakPreviewScope.isPreview(context);

/// Starts [c] looping, or parks it at [park] when motion should be frozen.
/// Call from `didChangeDependencies` so it reacts to setting changes.
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
