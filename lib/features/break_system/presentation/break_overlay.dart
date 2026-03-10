import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/break_system/domain/break_model.dart';
import 'package:standup/ui/theme/app_theme.dart';
import 'package:standup/ui/widgets/countdown_timer.dart';
import 'package:standup/ui/widgets/progress_ring.dart';

class BreakOverlay extends StatelessWidget {
  const BreakOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        final timerEngine = controller.timerEngine;
        final breakInfo = timerEngine.activeBreak;

        if (breakInfo == null) return const SizedBox.shrink();

        final progress =
            timerEngine.countdownSeconds / breakInfo.durationSeconds;
        final ringColor = breakInfo.isLong
            ? AppTheme.longBreakColor
            : AppTheme.shortBreakColor;

        return Material(
          color: Colors.transparent,
          child: AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 400),
            child: Container(
              color: AppTheme.overlayBackground,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(breakInfo.title, style: AppTheme.breakTitleStyle),
                    const SizedBox(height: 48),
                    ProgressRing(
                      progress: progress,
                      size: 240,
                      strokeWidth: 8,
                      color: ringColor,
                      child: CountdownTimerWidget(
                        remainingSeconds: timerEngine.countdownSeconds,
                        totalSeconds: breakInfo.durationSeconds,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        breakInfo.tip,
                        style: AppTheme.tipStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 64),
                    _buildSkipButton(context, controller),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkipButton(BuildContext context, BreakController controller) {
    final settings =
        Provider.of<BreakController>(context, listen: false);
    // Hide skip in strict mode
    if (settings.timerEngine.activeBreak == null) return const SizedBox();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => controller.skipCurrentBreak(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          child: const Text('Skip break', style: AppTheme.skipButtonStyle),
        ),
      ),
    );
  }
}
