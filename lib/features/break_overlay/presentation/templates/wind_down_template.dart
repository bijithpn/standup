import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

class WindDownTemplate extends StatelessWidget {
  const WindDownTemplate({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsService>().stats;
    final breakController = context.watch<BreakController>();
    final size = MediaQuery.of(context).size;
    final compact = size.width < 680;

    return Material(
      color: const Color(0xFF090A0F),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _WindDownBackdropPainter()),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 24 : 48,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sunset Orange badge icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF97316,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFFF97316,
                            ).withValues(alpha: 0.24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFF97316,
                              ).withValues(alpha: 0.1),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.sunset,
                          size: 24,
                          color: Color(0xFFF97316),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title & subtitle
                      const Text(
                        'Workday Wrap-up',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Inter',
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Time to disconnect and recharge.\nHere's your daily summary.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontFamily: 'Inter',
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Stats glass panel
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: _StatItem(
                                icon: LucideIcons.timer,
                                value:
                                    '${(stats.dailyUsageMinutes / 60).toStringAsFixed(1)}h',
                                label: 'Focus Time',
                                iconColor: const Color(0xFF38BDF8),
                              ),
                            ),
                            _Divider(),
                            Expanded(
                              child: _StatItem(
                                icon: LucideIcons.coffee,
                                value: '${stats.breaksCompleted}',
                                label: 'Breaks Taken',
                                iconColor: const Color(0xFFFB923C),
                              ),
                            ),
                            _Divider(),
                            Expanded(
                              child: _StatItem(
                                icon: LucideIcons.trendingUp,
                                value: '${stats.productivityScore}%',
                                label: 'Efficiency',
                                iconColor: const Color(0xFF34D399),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Glossy finish day CTA button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () =>
                              breakController.completeCurrentBreak(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                LucideIcons.logOut,
                                size: 16,
                                color: Colors.black,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Finish My Day',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor.withValues(alpha: 0.7)),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _WindDownBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // twilight base gradient
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF0D0F14), // Deep indigo
        Color(0xFF06070A), // Cosmic black
      ],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = bgGradient.createShader(Offset.zero & size),
    );

    // Warm soft sunset radial glow from the bottom
    final center = Offset(size.width * 0.5, size.height);
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(
                0xFFEA580C,
              ).withValues(alpha: 0.06), // sunset orange glow
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.shortestSide * 0.45),
          );
    canvas.drawCircle(center, size.shortestSide * 0.45, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
