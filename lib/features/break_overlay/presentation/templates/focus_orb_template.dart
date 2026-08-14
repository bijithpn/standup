import 'package:flutter/material.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/domain/break_overlay_theme.dart';

class FocusOrbTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const FocusOrbTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isShort = breakInfo.type == BreakType.short;
    final breakName = isShort ? 'Eye rest' : 'Long break';
    const accent = Color(0xFF8BC9D4);

    return ColoredBox(
      color: BreakOverlayTheme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: _OrbPainter(accent: accent)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w200,
                    fontFamily: BreakOverlayTheme.fontFamily,
                    fontFeatures: [FontFeature.tabularFigures()],
                    letterSpacing: -2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  breakName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.33),
                    fontSize: BreakOverlayTheme.labelFontSize,
                    fontWeight: FontWeight.w400,
                    fontFamily: BreakOverlayTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          if (!settings.strictMode && onSkip != null)
            Positioned(
              bottom: BreakOverlayTheme.skipBottom,
              right: BreakOverlayTheme.skipRight,
              child: GestureDetector(
                onTap: onSkip,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: BreakOverlayTheme.textDim,
                      fontSize: BreakOverlayTheme.labelFontSize,
                      fontWeight: FontWeight.w400,
                      fontFamily: BreakOverlayTheme.fontFamily,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final Color accent;

  const _OrbPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = BreakOverlayTheme.background,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.35,
          colors: [accent.withValues(alpha: 0.12), Colors.transparent],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
