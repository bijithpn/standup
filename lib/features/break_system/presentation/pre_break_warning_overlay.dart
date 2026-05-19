import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

        if (!timerEngine.isPreBreak || timerEngine.state == TimerState.breakActive) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Subtle dimming of the screen
              AnimatedContainer(
                duration: const Duration(seconds: 1),
                color: Colors.black.withValues(alpha: 0.3),
              ),
              
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 450;
                    
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          width: isNarrow ? constraints.maxWidth * 0.85 : 420,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.shortBreakColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.timer,
                                  color: AppTheme.shortBreakColor,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'BREAK STARTING SOON',
                                textAlign: TextAlign.center,
                                style: AppTheme.sectionTitle.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Time to rest your eyes in 20 seconds',
                                textAlign: TextAlign.center,
                                style: AppTheme.subHeaderStyle.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
