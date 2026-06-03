import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';
import 'package:breakmate/features/break_overlay/presentation/widgets/shared_overlay_widgets.dart';

class ProductivityHudTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const ProductivityHudTemplate({
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
        ? const Color(0xFF38BDF8) // Neon Cyan
        : const Color(0xFF34D399); // Neon Mint
    final size = MediaQuery.of(context).size;
    final compact = size.width < 760;

    return Material(
      color: const Color(0xFF050608),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: _HudGrid(accent: accent)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(compact ? 24 : 36),
              child: Column(
                children: [
                  Row(
                    children: [
                      _SignalChip(
                        accent: accent,
                        icon: isShortBreak
                            ? LucideIcons.eye
                            : LucideIcons.timer,
                        label: isShortBreak ? 'VISUAL RESET' : 'RECOVERY MODE',
                      ),
                      const Spacer(),
                      _TelemetryTime(
                        label: 'LOCAL TIME',
                        value: DateFormat('HH:mm').format(DateTime.now()),
                      ),
                    ],
                  ),
                  const Spacer(),
                  RepaintBoundary(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '[ ${_formatTime(remainingSeconds)} ]',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 64 : 96,
                              height: 0.9,
                              fontWeight: FontWeight.w200,
                              fontFamily: 'Inter',
                              letterSpacing: -2.0,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _SegmentedProgressIndicator(
                            value: progress,
                            accent: accent,
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _TelemetryValue(
                                label: 'PHASE',
                                value: isShortBreak ? 'Eyes' : 'Body',
                                accent: accent,
                              ),
                              _TelemetryValue(
                                label: 'DURATION',
                                value: totalSeconds < 60
                                    ? '${totalSeconds}s'
                                    : '${totalSeconds ~/ 60}m',
                                accent: accent,
                              ),
                              _TelemetryValue(
                                label: 'PROGRESS',
                                value: '${(progress * 100).round()}%',
                                accent: accent,
                              ),
                              _TelemetryValue(
                                label: 'STATE',
                                value: settings.strictMode ? 'Locked' : 'Open',
                                accent: accent,
                              ),
                            ],
                          ),
                          // Wellness note — hidden when showExercisesInBreak is off
                          if (settings.showExercisesInBreak) ...[
                            const SizedBox(height: 36),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isShortBreak
                                        ? 'DEFOCUS AND RESET'
                                        : 'RECOVER BEFORE NEXT PUSH',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    breakInfo.tip,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 14,
                                      height: 1.5,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.activity,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LOW STIMULUS HUD MODE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const Spacer(),
                      if (onSkip != null && !settings.strictMode)
                        SkipBreakButton(onSkip: onSkip!),
                    ],
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

class _HudGrid extends StatelessWidget {
  final Color accent;
  const _HudGrid({required this.accent});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HudGridPainter(accent: accent));
  }
}

class _HudGridPainter extends CustomPainter {
  final Color accent;
  _HudGridPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF06070B);
    canvas.drawRect(Offset.zero & size, bg);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.012)
      ..strokeWidth = 1;
    const double gap = 48.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Top-left and bottom-right subtle corner accent lines
    final bracketPaint = Paint()
      ..color = accent.withValues(alpha: 0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const double padding = 20.0;
    const double length = 12.0;

    // Top Left
    final pathTL = Path()
      ..moveTo(padding, padding + length)
      ..lineTo(padding, padding)
      ..lineTo(padding + length, padding);
    canvas.drawPath(pathTL, bracketPaint);

    // Top Right
    final pathTR = Path()
      ..moveTo(size.width - padding, padding + length)
      ..lineTo(size.width - padding, padding)
      ..lineTo(size.width - padding - length, padding);
    canvas.drawPath(pathTR, bracketPaint);

    // Bottom Left
    final pathBL = Path()
      ..moveTo(padding, size.height - padding - length)
      ..lineTo(padding, size.height - padding)
      ..lineTo(padding + length, size.height - padding);
    canvas.drawPath(pathBL, bracketPaint);

    // Bottom Right
    final pathBR = Path()
      ..moveTo(size.width - padding, size.height - padding - length)
      ..lineTo(size.width - padding, size.height - padding)
      ..lineTo(size.width - padding - length, size.height - padding);
    canvas.drawPath(pathBR, bracketPaint);
  }

  @override
  bool shouldRepaint(covariant _HudGridPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _SignalChip extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String label;

  const _SignalChip({
    required this.accent,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryTime extends StatelessWidget {
  final String label;
  final String value;

  const _TelemetryTime({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _TelemetryValue extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _TelemetryValue({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 3,
                height: 9,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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

class _SegmentedProgressIndicator extends StatelessWidget {
  final double value;
  final Color accent;
  final int segments = 24;

  const _SegmentedProgressIndicator({
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(segments, (index) {
        final isFilled = (index / segments) < value;
        return Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: isFilled ? accent : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: isFilled
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
