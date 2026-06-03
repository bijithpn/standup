import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';

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

  String _formatDurationLabel(int seconds) {
    if (seconds < 60) return '$seconds sec break';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (remainder == 0) return '$minutes min break';
    return '$minutes min $remainder sec break';
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0
        ? (1 - (remainingSeconds / totalSeconds)).clamp(0.0, 1.0)
        : 0.0;
    final isShortBreak = breakInfo.type == BreakType.short;
    final accent = isShortBreak
        ? const Color(0xFF38BDF8) // Vibrant Neon Cyan
        : const Color(0xFF34D399); // Ambient Neon Emerald
    final media = MediaQuery.of(context).size;
    final compact = media.width < 760 || media.height < 620;
    final dialSize = compact ? 190.0 : 250.0;
    final showNotes = settings.showExercisesInBreak;

    return Material(
      color: const Color(0xFF090A0F),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: _MinimalField(accent: accent)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 24 : 48,
                    vertical: compact ? 20 : 36,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (compact ? 40 : 72),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _TopRail(
                          accent: accent,
                          label: isShortBreak ? 'EYE RESET' : 'PAUSE WINDOW',
                          durationLabel: _formatDurationLabel(totalSeconds),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              RepaintBoundary(
                                child: _BreakDial(
                                  accent: accent,
                                  size: dialSize,
                                  progress: progress,
                                  time: _formatTime(remainingSeconds),
                                  durationLabel: _formatDurationLabel(
                                    totalSeconds,
                                  ),
                                  icon: isShortBreak
                                      ? LucideIcons.eye
                                      : LucideIcons.leaf,
                                ),
                              ),
                              const SizedBox(height: 36),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 500,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      isShortBreak ? 'Look away' : 'Step back',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: compact ? 28 : 34,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Inter',
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    if (showNotes) ...[
                                      const SizedBox(height: 18),
                                      _WellnessNote(
                                        accent: accent,
                                        text: breakInfo.tip,
                                        reason: breakInfo.triggerReason,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _BottomRail(
                          currentTime: DateFormat(
                            'HH:mm',
                          ).format(DateTime.now()),
                          onSkip: settings.strictMode ? null : onSkip,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalField extends StatelessWidget {
  final Color accent;
  const _MinimalField({required this.accent});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MinimalFieldPainter(accent: accent));
  }
}

class _MinimalFieldPainter extends CustomPainter {
  final Color accent;
  _MinimalFieldPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF08090C);
    canvas.drawRect(Offset.zero & size, background);

    // Drifting ambient glow spots
    final center1 = Offset(size.width * 0.1, size.height * 0.15);
    final glowPaint1 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: 0.08),
              accent.withValues(alpha: 0.02),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center1, radius: size.width * 0.4),
          );
    canvas.drawCircle(center1, size.width * 0.4, glowPaint1);

    final center2 = Offset(size.width * 0.9, size.height * 0.85);
    final glowPaint2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: 0.05),
              accent.withValues(alpha: 0.015),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center2, radius: size.width * 0.35),
          );
    canvas.drawCircle(center2, size.width * 0.35, glowPaint2);

    // Technical mesh line grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 1;
    const double gridSpacing = 44.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MinimalFieldPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _TopRail extends StatelessWidget {
  final Color accent;
  final String label;
  final String durationLabel;

  const _TopRail({
    required this.accent,
    required this.label,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            durationLabel.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontFamily: 'Inter',
            ),
          ),
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
  final String durationLabel;
  final IconData icon;

  const _BreakDial({
    required this.accent,
    required this.size,
    required this.progress,
    required this.time,
    required this.durationLabel,
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
              Icon(icon, size: size < 200 ? 18 : 22, color: accent),
              const SizedBox(height: 14),
              Text(
                time,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size < 200 ? 40 : 54,
                  fontWeight: FontWeight.w300,
                  fontFamily: 'Inter',
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'REMAINING',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: size < 200 ? 8 : 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
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

    // Thin inner radar rings
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.04);
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(center, radius - 20 - (i * 20), basePaint);
    }

    // Dial track indicator
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(center, radius - 10, trackPaint);

    // Neon shadow glow behind the progress arc
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..color = accent.withValues(alpha: 0.2);

    // Active progress arc
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = accent;

    final rect = Rect.fromCircle(center: center, radius: radius - 10);

    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        glowPaint,
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        progressPaint,
      );
    }

    // Sleek outer ticks
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    const int tickCount = 48;
    for (int i = 0; i < tickCount; i++) {
      final angle = (math.pi * 2 / tickCount) * i;
      final double len = i % 4 == 0 ? 6.0 : 3.0;
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - 2),
        center.dy + math.sin(angle) * (radius - 2),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 2 - len),
        center.dy + math.sin(angle) * (radius - 2 - len),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BreakDialPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accent != accent;
  }
}

class _WellnessNote extends StatelessWidget {
  final Color accent;
  final String text;
  final String? reason;

  const _WellnessNote({required this.accent, required this.text, this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.notebookText, size: 14, color: accent),
              const SizedBox(width: 8),
              Text(
                'WELLNESS FOCUS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          if (reason != null) ...[
            const SizedBox(height: 12),
            Text(
              reason!,
              style: TextStyle(
                color: accent.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 14,
              height: 1.5,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Text(
            currentTime,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const Spacer(),
        if (onSkip != null) SkipBreakButton(onSkip: onSkip!),
      ],
    );
  }
}
