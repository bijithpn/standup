import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class BreathingAssistant extends StatefulWidget {
  final bool isShortBreak;
  const BreathingAssistant({super.key, required this.isShortBreak});

  @override
  State<BreathingAssistant> createState() => _BreathingAssistantState();
}

class _BreathingAssistantState extends State<BreathingAssistant>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _opacityAnimation = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isShortBreak
        ? AppTheme.shortBreak
        : AppTheme.longBreak;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isInhaling = _controller.status == AnimationStatus.forward;
        return Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Outer glow
                Container(
                  width: 140 * _scaleAnimation.value,
                  height: 140 * _scaleAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: 0.15 * _opacityAnimation.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Inner ring
                Container(
                  width: 90 * _scaleAnimation.value,
                  height: 90 * _scaleAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: _opacityAnimation.value),
                      width: 2,
                    ),
                  ),
                ),
                // Core dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              isInhaling ? 'BREATHE IN' : 'BREATHE OUT',
              style: TextStyle(
                color: AppTheme.textPrimary.withValues(alpha: 0.9),
                letterSpacing: 4,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isInhaling ? 'Fill your lungs slowly' : 'Release all tension',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );
      },
    );
  }
}
