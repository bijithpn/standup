import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

class PaperLightTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const PaperLightTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  static const _page = BreakPalette(
    canvas: Color(0xFF252726),
    canvasRaised: Color(0xFF2D302E),
    surface: Color(0xFF2D302E),
    border: Color(0x426B746B),
    track: Color(0x426B746B),
    textPrimary: Color(0xFFE0E1D8),
    textSecondary: Color(0xFFBEC3B8),
    textMuted: Color(0xFFA6AEA1),
    isDark: true,
  );
  static const _penBlue = Color(0xFFA7BCA6);
  static const double _rule = 48;

  TextStyle _serif(double size, Color color, {FontWeight? weight}) =>
      BreakOverlayTheme.serif.copyWith(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w400,
        color: color,
        fontFeatures: BreakOverlayTheme.tabular,
      );

  @override
  Widget build(BuildContext context) {
    final pen = BreakOverlayTheme.resolveAccent(
      settings.templateAccentOverrides,
      'paper_light',
      _penBlue,
    );
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final showTip = settings.showExercisesInBreak && breakInfo.tip.isNotEmpty;

    return BreakScaffold(
      palette: _page,
      canvas: _page.canvas,
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: pen,
      background: Padding(
        padding: const EdgeInsets.all(40),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _page.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _page.border),
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 144,
            top: _rule * 2,
            right: 128,
            child: BreakEntrance(
              scale: false,
              child: Text(
                BreakKind.of(breakInfo).label,
                style: _serif(
                  28,
                  breakReadableColor(pen, _page.surface),
                  weight: FontWeight.w600,
                ).copyWith(height: _rule / 28),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              left: 144,
              top: _rule * 4,
              width: 620,
              child: BreakEntrance(
                delay: BreakEntrance.stagger(1),
                scale: false,
                child: Text(
                  breakInfo.tip,
                  style: _serif(
                    32,
                    _page.textPrimary,
                  ).copyWith(height: _rule / 32, fontStyle: FontStyle.normal),
                ),
              ),
            ),
          Positioned(
            left: 144,
            bottom: _rule * 2,
            child: BreakEntrance(
              delay: BreakEntrance.stagger(2),
              scale: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BreakCountdown(
                    seconds: remainingSeconds,
                    textAlign: TextAlign.left,
                    style: _serif(
                      176,
                      _page.textPrimary,
                      weight: FontWeight.w300,
                    ).copyWith(height: 1.0, letterSpacing: -4),
                    color: breakClockColor(
                      settings,
                      _page,
                      fallback: _page.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 420,
                    child: BreakSmoothProgress(
                      progress: progress,
                      builder: (context, anim) => AnimatedBuilder(
                        animation: anim,
                        builder: (context, _) => LinearProgressIndicator(
                          value: anim.value,
                          minHeight: 3,
                          color: pen,
                          backgroundColor: _page.track,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
