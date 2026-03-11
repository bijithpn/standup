import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/statistics/stats_service.dart';
import 'package:standup/features/statistics/stats_model.dart';
import 'package:standup/ui/theme/app_theme.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:window_manager/window_manager.dart';

/// Enhanced menu bar popover panel showing timer status and quick actions
class MenuBarPopover extends StatelessWidget {
  const MenuBarPopover({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        final timerEngine = controller.timerEngine;
        final stats = sl<StatsService>().load();
        final timeUntilBreak = timerEngine.timeUntilNextShortBreak;

        return Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.contentBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with app name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accentColor, AppTheme.accentColor.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.infinite,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'BreakMate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Status indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: timerEngine.state == TimerState.breakActive
                          ? AppTheme.shortBreakColor
                          : AppTheme.accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (timerEngine.state == TimerState.breakActive
                                  ? AppTheme.shortBreakColor
                                  : AppTheme.accentColor)
                              .withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppTheme.borderColor),

              // Timer display
              _buildTimerSection(timerEngine, timeUntilBreak),
              const Divider(height: 24, color: AppTheme.borderColor),

              // Quick actions
              _buildQuickActions(controller),
              const Divider(height: 24, color: AppTheme.borderColor),

              // Stats preview
              _buildStatsPreview(stats),
              const Divider(height: 24, color: AppTheme.borderColor),

              // Bottom actions
              _buildBottomActions(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimerSection(TimerEngine timerEngine, Duration timeUntilBreak) {
    final isBreak = timerEngine.state == TimerState.breakActive;
    final mins = timeUntilBreak.inMinutes;
    final secs = (timeUntilBreak.inSeconds % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isBreak ? 'Break Time' : 'Next Break In',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              isBreak ? CupertinoIcons.square_arrow_up_on_square : CupertinoIcons.device_laptop,
              size: 16,
              color: isBreak ? AppTheme.shortBreakColor : AppTheme.accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              '$mins:$secs',
              style: TextStyle(
                color: isBreak ? AppTheme.shortBreakColor : Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (isBreak) ...[
          const SizedBox(height: 8),
          Text(
            timerEngine.activeBreak?.title ?? 'Break',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActions(BreakController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: controller.isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
                label: controller.isPaused ? 'Resume' : 'Pause',
                color: AppTheme.accentColor,
                onTap: () => controller.togglePause(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: CupertinoIcons.bolt_fill,
                label: 'Break Now',
                color: AppTheme.shortBreakColor,
                onTap: () => controller.takeBreakNow(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: CupertinoIcons.forward_fill,
                label: 'Skip Next',
                color: AppTheme.textMuted,
                onTap: () => controller.skipNextBreak(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsPreview(StatsModel stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Progress',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StatCard(
              icon: CupertinoIcons.checkmark_seal_fill,
              value: stats.breaksCompleted.toString(),
              label: 'Completed',
              color: AppTheme.shortBreakColor,
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: CupertinoIcons.flame_fill,
              value: stats.currentStreak.toString(),
              label: 'Day Streak',
              color: AppTheme.upcomingBreakColor,
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: CupertinoIcons.chart_bar_fill,
              value: '${stats.productivityScore}%',
              label: 'Score',
              color: AppTheme.accentColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () async {
              await windowManager.show();
              await windowManager.focus();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            await windowManager.setPreventClose(false);
            await windowManager.close();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              CupertinoIcons.power,
              color: Colors.white54,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
