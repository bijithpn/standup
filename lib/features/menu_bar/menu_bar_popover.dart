import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:standup/core/services/overlay_window_service.dart';
import 'package:standup/core/services/timer_engine.dart';
import 'package:standup/features/break_system/application/break_controller.dart';
import 'package:standup/features/analytics/stats_service.dart';
import 'package:standup/features/analytics/stats_model.dart';
import 'package:standup/shared/theme/app_theme.dart';
import 'package:standup/app/dependency_injection.dart';
import 'package:window_manager/window_manager.dart';

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
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(timerEngine),
              const SizedBox(height: 16),
              _buildTimerSection(timerEngine, timeUntilBreak),
              const SizedBox(height: 16),
              _buildQuickActions(controller),
              const SizedBox(height: 16),
              _buildStatsPreview(stats),
              const SizedBox(height: 16),
              _buildBottomActions(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(TimerEngine timerEngine) {
    final isBreak = timerEngine.state == TimerState.breakActive;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: const Icon(
            LucideIcons.coffee,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'BreakMate',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isBreak ? AppTheme.shortBreak : AppTheme.success,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isBreak ? AppTheme.shortBreak : AppTheme.success)
                    .withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimerSection(TimerEngine timerEngine, Duration timeUntilBreak) {
    final isBreak = timerEngine.state == TimerState.breakActive;
    final mins = timeUntilBreak.inMinutes;
    final secs = (timeUntilBreak.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gray900,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBreak ? 'BREAK IN PROGRESS' : 'NEXT BREAK IN',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$mins:$secs',
                style: TextStyle(
                  color: isBreak ? AppTheme.shortBreak : AppTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Icon(
                isBreak ? LucideIcons.coffee : LucideIcons.clock,
                size: 20,
                color: isBreak ? AppTheme.shortBreak : AppTheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BreakController controller) {
    final isBreak = controller.isBreakActive;

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
                icon: controller.isPaused ? LucideIcons.play : LucideIcons.pause,
                label: controller.isPaused ? 'Resume' : 'Pause',
                color: isBreak ? AppTheme.textMuted : AppTheme.primary,
                onTap: isBreak ? () {} : () => controller.togglePause(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: isBreak
                  ? _ActionButton(
                      icon: LucideIcons.skipForward,
                      label: 'Skip',
                      color: AppTheme.shortBreak,
                      onTap: () => controller.skipCurrentBreak(),
                    )
                  : _ActionButton(
                      icon: LucideIcons.zap,
                      label: 'Break Now',
                      color: AppTheme.shortBreak,
                      onTap: () => controller.takeBreakNow(),
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
              icon: LucideIcons.checkCircle,
              value: stats.breaksCompleted.toString(),
              label: 'Done',
              color: AppTheme.success,
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: LucideIcons.flame,
              value: stats.currentStreak.toString(),
              label: 'Streak',
              color: AppTheme.warning,
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: LucideIcons.target,
              value: '${stats.productivityScore}%',
              label: 'Score',
              color: AppTheme.primary,
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
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                sl<OverlayWindowService>().showDashboard();
                await windowManager.show();
                await windowManager.focus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.gray800,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.settings, size: 14, color: AppTheme.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      'Settings',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () async {
              await windowManager.setPreventClose(false);
              await windowManager.close();
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.gray800,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(
                LucideIcons.power,
                color: AppTheme.textMuted,
                size: 16,
              ),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: color.withValues(alpha: 0.2)),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.gray900,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
