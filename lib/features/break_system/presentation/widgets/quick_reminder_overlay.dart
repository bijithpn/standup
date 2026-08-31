import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/break_system/presentation/widgets/break_start_warning_overlay.dart';

class QuickReminderOverlay extends StatelessWidget {
  final String? reminderType;
  final String overlayType;
  final Animation<double> fadeAnimation;
  final String title;
  final int durationSeconds;

  const QuickReminderOverlay({
    super.key,
    required this.reminderType,
    required this.overlayType,
    required this.fadeAnimation,
    required this.title,
    required this.durationSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final isPosture = reminderType == 'posture';
    final isBreakStart =
        reminderType == 'breakStart' || overlayType == 'preBreakWarning';

    if (isBreakStart) {
      return BreakStartWarningOverlay(
        fadeAnimation: fadeAnimation,
        title: title,
        durationSeconds: durationSeconds,
        isPreBreak: overlayType == 'preBreakWarning',
      );
    }

    return Center(
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(
            parent: fadeAnimation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          ),
        ),
        child: Container(
          width: 380,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.05),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceCard,
                AppTheme.surfaceCard.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  isPosture ? 'POSTURE CHECK' : 'EYE REFRESH',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isPosture
                      ? CupertinoIcons.person_crop_circle_badge_checkmark
                      : CupertinoIcons.eye_fill,
                  color: AppTheme.accent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isPosture ? 'Check Your Posture' : 'Rest Your Eyes',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isPosture
                    ? 'Sit up straight, relax your neck, and drop your shoulders.'
                    : 'Blink a few times and focus on something far away.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
