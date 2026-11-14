import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:flutter/material.dart';
import '../../domain/break_model.dart';
import '../../../settings/settings_model.dart';

/// Plain, unscaled layout for high contrast and large text. No photo or animation
/// can reduce legibility, and short windows can scroll through the instructions.
class AccessibleBreakView extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remaining;
  final String? instructions;
  final String? exerciseTitle;
  const AccessibleBreakView({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remaining,
    this.instructions,
    this.exerciseTitle,
  });
  @override
  Widget build(BuildContext context) {
    final dark =
        settings.overlayThemeMode != 'light' &&
        (settings.overlayThemeMode != 'system' ||
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final contrast =
        settings.experience.highContrast || MediaQuery.highContrastOf(context);
    final palette = BreakPalette.forMode(
      settings.overlayThemeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final ink = contrast
        ? (dark ? Colors.white : Colors.black)
        : palette.textPrimary;
    return ColoredBox(
      color: contrast ? (dark ? Colors.black : Colors.white) : palette.canvas,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 100, 32, 140),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: DefaultTextStyle(
                style: TextStyle(color: ink, fontSize: 20, height: 1.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        settings.experience.hasExerciseRestrictions
                            ? (settings.showExercisesInBreak
                                  ? exerciseTitle ?? 'A comfortable pause'
                                  : 'A comfortable pause')
                            : breakInfo.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '$remaining seconds remaining',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      settings.experience.hasExerciseRestrictions
                          ? 'Take a comfortable pause. You can rest quietly.'
                          : breakInfo.tip,
                      textAlign: TextAlign.center,
                    ),
                    if (settings.showExercisesInBreak &&
                        instructions != null &&
                        instructions!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(instructions!, textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
