import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _cream = Color(0xFFF7F1E3);
const _forest = Color(0xFF1F3A2D);

const _paper = BreakPalette(
  canvas: Color(0xFF1C2622),
  canvasRaised: Color(0xFF26332C),
  surface: Color(0xFF26332C),
  border: Color(0x426B746B),
  track: Color(0x426B746B),
  textPrimary: Color(0xFFDEE5DA),
  textSecondary: Color(0xFFBDCCBB),
  textMuted: Color(0xFFA3B69F),
  isDark: true,
);

class SplitViewTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const SplitViewTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    const palette = _paper;
    final kind = BreakKind.of(breakInfo);
    final accent = BreakOverlayTheme.resolveAccent(
      settings.templateAccentOverrides,
      'split_view',
      palette.textPrimary,
    );
    final progress = breakProgress(remainingSeconds, totalSeconds);
    final complete = breakIsComplete(context, remainingSeconds, totalSeconds);
    final reason = breakInfo.triggerReason;

    return BreakScaffold(
      palette: palette,
      onSkip: onSkip,
      strictMode: settings.strictMode,
      accent: _forest,
      background: Row(
        children: [
          Expanded(
            child: ClipRect(
              child: CustomPaint(
                painter: _FieldPainter(),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const Expanded(child: SizedBox.expand()),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: 640,
            height: 800,
            child: Center(
              child: BreakEntrance(
                child: BreakCompletionPulse(
                  complete: complete,
                  child: BreakProgressRing(
                    size: 320,
                    strokeWidth: 6,
                    progress: progress,
                    color: accent,
                    trackColor: _cream.withValues(alpha: 0.28),
                    flash: complete ? 0.5 : 0,
                    child: BreakCountdown(
                      seconds: remainingSeconds,
                      style: BreakOverlayTheme.hero.copyWith(
                        fontSize: 84,
                        letterSpacing: -3,
                      ),
                      color: breakClockColor(
                        settings,
                        palette,
                        fallback: palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 640 + 88,
            right: 80,
            top: 0,
            height: 800,
            child: Center(
              child: BreakEntrance(
                delay: BreakEntrance.stagger(1),
                scale: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label,
                      style: BreakOverlayTheme.serif.copyWith(
                        fontSize: 22,
                        fontStyle: FontStyle.italic,
                        color: palette.textSecondary,
                      ),
                    ),
                    if (breakInfo.tip.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Text(
                          breakInfo.tip,
                          style: BreakOverlayTheme.serif.copyWith(
                            fontSize: 32,
                            height: 1.22,
                            letterSpacing: -0.8,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                    if (settings.showExercisesInBreak &&
                        reason != null &&
                        reason.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      BreakTip(reason, textAlign: TextAlign.left),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF24392F),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _cream.withValues(alpha: 0.16);
    final c = size.center(Offset.zero);
    for (final r in [230.0, 300.0, 380.0, 470.0]) {
      canvas.drawCircle(c, r, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) => false;
}
