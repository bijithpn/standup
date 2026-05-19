import 'package:flutter/material.dart';
import 'package:standup/shared/theme/app_theme.dart';

class BreathingAssistant extends StatefulWidget {
  final bool isShortBreak;
  const BreathingAssistant({super.key, required this.isShortBreak});

  @override
  State<BreathingAssistant> createState() => _BreathingAssistantState();
}

class _BreathingAssistantState extends State<BreathingAssistant> with SingleTickerProviderStateMixin {
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

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _opacityAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isInhaling = _controller.status == AnimationStatus.forward;
        return Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                Container(
                  width: 120 * _scaleAnimation.value,
                  height: 120 * _scaleAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.accentColor.withValues(alpha: 0.2 * _opacityAnimation.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Inner ring
                Container(
                  width: 80 * _scaleAnimation.value,
                  height: 80 * _scaleAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: _opacityAnimation.value),
                      width: 2,
                    ),
                  ),
                ),
                // Core dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              isInhaling ? 'INHALE' : 'EXHALE',
              style: AppTheme.sectionTitle.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: 6,
                fontSize: 10,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        );
      },
    );
  }
}
