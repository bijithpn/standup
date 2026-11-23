import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

/// Centered icon + text reminder on a dimmed backdrop, shown when a full poster is allowed.
class PosterReminderOverlay extends StatelessWidget {
  final IconData icon;
  final String text;
  final Animation<double> fadeAnimation;

  const PosterReminderOverlay({
    super.key,
    required this.icon,
    required this.text,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: fadeAnimation,
          child: ColoredBox(color: AppTheme.scrim),
        ),
        Center(
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: fadeAnimation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1.0).animate(
                CurvedAnimation(
                  parent: fadeAnimation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeIn,
                ),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: AppTheme.accent),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
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
    );
  }
}
