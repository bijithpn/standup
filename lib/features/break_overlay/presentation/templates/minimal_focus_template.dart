import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class MinimalFocusTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const MinimalFocusTemplate({
    super.key,
    required this.breakInfo,
    required this.settings,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.onSkip,
  });

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0
        ? (1 - (remainingSeconds / totalSeconds)).clamp(0.0, 1.0)
        : 0.0;
    final isShortBreak = breakInfo.type == BreakType.short;
    final accent = isShortBreak
        ? const Color(0xFF7DD3FC)
        : const Color(0xFFA7F3D0);
    final media = MediaQuery.of(context).size;
    final compact = media.width < 760 || media.height < 620;
    final dialSize = compact ? 224.0 : 292.0;

    return Material(
      color: const Color(0xFF080A0C),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: _MinimalField()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 24 : 48,
                vertical: compact ? 18 : 34,
              ),
              child: Column(
                children: [
                  _TopRail(
                    accent: accent,
                    label: isShortBreak ? 'EYE RESET' : 'PAUSE WINDOW',
                  ),
                  const Spacer(),
                  RepaintBoundary(
                    child: _BreakDial(
                      accent: accent,
                      size: dialSize,
                      progress: progress,
                      time: _formatTime(remainingSeconds),
                      icon: isShortBreak ? LucideIcons.eye : LucideIcons.leaf,
                    ),
                  ),
                  SizedBox(height: compact ? 28 : 40),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        Text(
                          isShortBreak ? 'Look away' : 'Step back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 30 : 38,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          breakInfo.tip,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.64),
                            fontSize: compact ? 14 : 16,
                            height: 1.5,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _BottomRail(
                    currentTime: DateFormat('HH:mm').format(DateTime.now()),
                    onSkip: settings.strictMode ? null : onSkip,
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

class _MinimalField extends StatelessWidget {
  const _MinimalField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MinimalFieldPainter());
  }
}

class _MinimalFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF080A0C);
    canvas.drawRect(Offset.zero & size, background);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    const gap = 48.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF0F766E).withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.42),
              radius: math.min(size.width, size.height) * 0.52,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopRail extends StatelessWidget {
  final Color accent;
  final String label;

  const _TopRail({required this.accent, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            fontFamily: 'Inter',
          ),
        ),
        const Spacer(),
        Icon(
          LucideIcons.sparkles,
          color: Colors.white.withValues(alpha: 0.42),
          size: 18,
        ),
      ],
    );
  }
}

class _BreakDial extends StatelessWidget {
  final Color accent;
  final double size;
  final double progress;
  final String time;
  final IconData icon;

  const _BreakDial({
    required this.accent,
    required this.size,
    required this.progress,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _BreakDialPainter(accent: accent, progress: progress),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: accent),
              const SizedBox(height: 18),
              Text(
                time,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size < 250 ? 48 : 62,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.44),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakDialPainter extends CustomPainter {
  final Color accent;
  final double progress;

  const _BreakDialPainter({required this.accent, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.12);
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = accent;

    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(center, radius - 16 - (i * 30), basePaint);
    }

    final rect = Rect.fromCircle(center: center, radius: radius - 16);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (int i = 0; i < 32; i++) {
      final angle = (math.pi * 2 / 32) * i;
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - 2),
        center.dy + math.sin(angle) * (radius - 2),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 10),
        center.dy + math.sin(angle) * (radius - 10),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BreakDialPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accent != accent;
  }
}

class _BottomRail extends StatelessWidget {
  final String currentTime;
  final VoidCallback? onSkip;

  const _BottomRail({required this.currentTime, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          currentTime,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const Spacer(),
        if (onSkip != null) ...[
          TextButton.icon(
            onPressed:
                onSkip, // Assuming postpone might route to same for now or separate
            icon: Icon(
              LucideIcons.clock,
              size: 14,
              color: Colors.white.withValues(alpha: 0.72),
            ),
            label: Text(
              'Postpone 5m',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontFamily: 'Inter',
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onSkip,
            icon: Icon(
              LucideIcons.skipForward,
              size: 14,
              color: Colors.white.withValues(alpha: 0.72),
            ),
            label: Text(
              'Skip Break',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontFamily: 'Inter',
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
