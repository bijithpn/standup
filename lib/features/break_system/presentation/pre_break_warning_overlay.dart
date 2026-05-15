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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const Duration(seconds: 20) <= const Duration(seconds: 20) 
                          ? const EdgeInsets.all(40)
                          : const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.timer,
                            color: AppTheme.shortBreakColor,
                            size: 48,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'BREAK STARTING SOON',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Prepare to rest your eyes in 20 seconds',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
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
      },
    );
  }
}
