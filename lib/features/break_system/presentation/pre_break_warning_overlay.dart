import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/shared/theme/app_theme.dart';

class PreBreakWarningOverlay extends StatelessWidget {
  const PreBreakWarningOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        final timerEngine = controller.timerEngine;

        if (!timerEngine.isPreBreak ||
            timerEngine.state == TimerState.breakActive) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Subtle backdrop
              Container(color: Colors.black.withValues(alpha: 0.4)),

              Center(
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.clock,
                          color: AppTheme.warning,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'Break Starting Soon',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Description
                      const Text(
                        'Time to rest in 20 seconds',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
