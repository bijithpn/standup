import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

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
        ? const Color(0xFF38BDF8)
        : const Color(0xFF34D399);
    final size = MediaQuery.of(context).size;
    final compact = size.width < 760;

    return Material(
      color: const Color(0xFF050608),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: _HudGrid()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(compact ? 22 : 36),
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
                      _TelemetryValue(
                        label: 'LOCAL',
                        value: DateFormat('HH:mm').format(DateTime.now()),
                      ),
                    ],
                  ),
                  const Spacer(),
                  RepaintBoundary(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _formatTime(remainingSeconds),
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 78 : 118,
                              height: 0.9,
                              fontWeight: FontWeight.w300,
                              fontFamily: 'Inter',
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Wrap(
                            spacing: 18,
                            runSpacing: 14,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _TelemetryValue(
                                label: 'PHASE',
                                value: isShortBreak ? 'Eyes' : 'Body',
                              ),
                              _TelemetryValue(
                                label: 'PROGRESS',
                                value: '${(progress * 100).round()}%',
                              ),
                              _TelemetryValue(
                                label: 'STATE',
                                value: settings.strictMode ? 'Locked' : 'Open',
                              ),
                            ],
                          ),
                          const SizedBox(height: 36),
                          Text(
                            isShortBreak
                                ? 'Defocus and reset.'
                                : 'Recover before the next push.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            breakInfo.tip,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 15,
                              height: 1.5,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.activity,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'low stimulus overlay',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const Spacer(),
                      if (onSkip != null && !settings.strictMode)
                        IconButton(
                          tooltip: 'Skip break',
                          onPressed: onSkip,
                          icon: const Icon(LucideIcons.chevronRight),
                          color: Colors.white.withValues(alpha: 0.72),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            fixedSize: const Size.square(42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
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
  const _HudGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HudGridPainter());
  }
}

class _HudGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF050608);
    canvas.drawRect(Offset.zero & size, bg);

    final major = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    final minor = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        x % 96 == 0 ? major : minor,
      );
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        y % 96 == 0 ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryValue extends StatelessWidget {
  final String label;
  final String value;

  const _TelemetryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.36),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
