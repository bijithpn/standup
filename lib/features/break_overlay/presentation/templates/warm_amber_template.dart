import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/domain/break_model.dart';
import 'package:breakmate/features/settings/settings_model.dart';

class WarmAmberTemplate extends StatelessWidget {
  final BreakModel breakInfo;
  final SettingsModel settings;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback? onSkip;

  const WarmAmberTemplate({
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
    const accent = Color(0xFFC49A4A);

    return ColoredBox(
      color: const Color(0xFF0A0A0F),
      child: ListenableBuilder(
        listenable: sl<StatsService>(),
        builder: (context, _) {
          final stats = sl<StatsService>().stats;
          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(child: CustomPaint(painter: _WarmAmberPainter())),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.sunset,
                        size: 22,
                        color: accent.withValues(alpha: 0.48),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Winding down',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 16),
                      Text(
                        '${stats.breaksCompleted} breaks today',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.33),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: 180,
                        height: 40,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white.withValues(
                              alpha: 0.48,
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 0.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            backgroundColor: Colors.transparent,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Inter',
                            ),
                          ),
                          onPressed: onSkip,
                          child: const Text('Done for today'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WarmAmberPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final gradient = RadialGradient(
      center: const Alignment(0, 0.5),
      radius: 0.8,
      colors: const [Color(0xFF1A1005), Color(0xFF08080F)],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
