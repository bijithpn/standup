import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class DuskGlowTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const DuskGlowTemplate({
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

  String _durationLabel() {
    final isShort = breakInfo.type == BreakType.short;
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    final dur = mins > 0
        ? (secs > 0 ? '$mins min $secs sec' : '$mins min')
        : '$totalSeconds sec';
    return isShort ? 'Wind down · $dur' : 'Pause · $dur';
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0
        ? (1 - remainingSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    const accent = Color(0xFFC4B5FD);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _DuskPainter()),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.moon,
                size: 20,
                color: Colors.white.withValues(alpha: 0.38),
              ),
              const SizedBox(height: 20),
              Text(
                _formatTime(remainingSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w200,
                  fontFamily: 'Inter',
                  fontFeatures: [FontFeature.tabularFigures()],
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _durationLabel(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 1,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    accent.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!settings.strictMode && onSkip != null)
          Positioned(
            bottom: 36,
            right: 40,
            child: GestureDetector(
              onTap: onSkip,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DuskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0F14), Color(0xFF06070A)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.5),
          radius: 0.7,
          colors: [
            const Color(0xFF1A0F2E).withValues(alpha: 1.0),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
