import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/break_kit/break_kit.dart';

const _sage = Color(0xFF6E9479);
const _cream = Color(0xFFF7F1E3);
const _forest = Color(0xFF1F3A2D);

const _paper = BreakPalette(
  canvas: _cream,
  canvasRaised: Color(0xFFEFE7D4),
  surface: Color(0xFFEFE7D4),
  border: Color(0x2E1F3A2D),
  track: Color(0x33F7F1E3),
  textPrimary: _forest,
  textSecondary: Color(0xFF3F5A4B),
  textMuted: Color(0xFF6B7F72),
  isDark: false,
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
      _cream,
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
                        fallback: _cream,
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
                        color: _sage,
                      ),
                    ),
                    if (breakInfo.tip.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Text(
                          breakInfo.tip,
                          style: BreakOverlayTheme.serif.copyWith(
                            fontSize: 42,
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
    canvas.drawRect(Offset.zero & size, Paint()..color = _sage);
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
