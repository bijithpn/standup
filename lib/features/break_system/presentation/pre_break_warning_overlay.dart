import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';

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

        final seconds = timerEngine.timeUntilNextShortBreak.inSeconds.clamp(
          0,
          999,
        );

        return Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black.withValues(alpha: 0.36)),
              Positioned(
                right: 28,
                bottom: 28,
                child: SafeArea(
                  child: Container(
                    width: 360,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101216).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.42),
                          blurRadius: 28,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFA7F3D0,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                LucideIcons.timerReset,
                                color: Color(0xFFA7F3D0),
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Break starts soon',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$seconds seconds to wrap up your flow',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.56,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Satoshi',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: seconds == 0 ? 1 : null,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFA7F3D0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _WarningButton(
                                label: 'Skip next',
                                icon: LucideIcons.skipForward,
                                onTap: controller.skipNextBreak,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _WarningButton(
                                label: 'Start now',
                                icon: LucideIcons.play,
                                onTap: controller.takeBreakNow,
                                emphasized: true,
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _WarningButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  const _WarningButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? const Color(0xFFA7F3D0) : Colors.white;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: emphasized ? 0.14 : 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color.withValues(alpha: 0.86)),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.86),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Satoshi',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
