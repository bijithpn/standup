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
    canvas: Color(0xFFF2F6FB),
    canvasRaised: Color(0xFFF8FAFD),
    surface: Color(0xFFFFFFFF),
    border: Color(0x2639506B),
    track: Color(0x3339506B),
    textPrimary: Color(0xFF3A3F47),
    textSecondary: Color(0xFF555C66),
    textMuted: Color(0xFF6B7380),
    isDark: false,
  );
  static const _penBlue = Color(0xFF2F5FA8);
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
      background: const CustomPaint(painter: _NotebookPainter()),
      child: Stack(
        children: [
          Positioned(
            left: 224,
            top: _rule * 2,
            right: 128,
            child: BreakEntrance(
              scale: false,
              child: Text(
                BreakKind.of(breakInfo).label,
                style: _serif(
                  28,
                  pen,
                  weight: FontWeight.w600,
                ).copyWith(height: _rule / 28),
              ),
            ),
          ),
          if (showTip)
            Positioned(
              left: 224,
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
                  ).copyWith(height: _rule / 32, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          Positioned(
            left: 224,
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

class _NotebookPainter extends CustomPainter {
  const _NotebookPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / 1280 < size.height / 800)
        ? size.width / 1280
        : size.height / 800;
    final left = (size.width - 1280 * scale) / 2;
    final top = (size.height - 800 * scale) / 2;
    final rule = Paint()
      ..color = const Color(0xFFBFD0E6)
      ..strokeWidth = 1;
    final step = PaperLightTemplate._rule * scale;
    for (var y = (top + 42 * scale) % step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final marginX = left + 176 * scale;
    canvas.drawLine(
      Offset(marginX, 0),
      Offset(marginX, size.height),
      Paint()
        ..color = const Color(0xFFE59A9A)
        ..strokeWidth = 1.5,
    );
    final hole = Paint()..color = const Color(0xFFDCE5F0);
    final edge = Paint()
      ..color = const Color(0xFFB3C3D9)
      ..style = PaintingStyle.stroke;
    for (final fy in [0.2, 0.5, 0.8]) {
      final c = Offset(left + 72 * scale, top + 800 * scale * fy);
      canvas.drawCircle(c, 15 * scale, hole);
      canvas.drawCircle(c, 15 * scale, edge);
    }
  }

  @override
  bool shouldRepaint(covariant _NotebookPainter old) => false;
}
