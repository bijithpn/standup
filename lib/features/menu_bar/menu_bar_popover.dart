import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/services/overlay_window_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/clock_out/clock_out_dialog.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:window_manager/window_manager.dart';

class MenuBarPopover extends StatelessWidget {
  const MenuBarPopover({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        final timerEngine = controller.timerEngine;
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
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 32,
                offset: const Offset(0, 16),
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
              _buildPauseReason(controller),
              const SizedBox(height: 12),
              _buildQuickActions(context, controller),
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
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(
            LucideIcons.coffee,
            color: AppTheme.textPrimary,
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        Text(
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

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBreak ? 'BREAK IN PROGRESS' : 'NEXT BREAK IN',
              style: TextStyle(
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
                    fontWeight: FontWeight.w400,
                    letterSpacing: -1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Icon(
                  isBreak ? LucideIcons.coffee : LucideIcons.clock,
                  size: 20,
                  color: isBreak ? AppTheme.shortBreak : AppTheme.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseReason(BreakController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.pauseReason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, BreakController controller) {
    final isBreak = controller.isBreakActive;
    final quietModeEnabled = controller.quietModeEnabled;
    final companionEnabled = controller.companionEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
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
                icon: controller.isPaused
                    ? LucideIcons.play
                    : LucideIcons.pause,
                label: controller.isPaused ? 'Resume' : 'Pause',
                color: isBreak ? AppTheme.textMuted : AppTheme.textPrimary,
                onTap: isBreak
                    ? null
                    : () {
                        controller.togglePause();
                        _showFeedback(
                          context,
                          controller.isPaused
                              ? 'Timer paused'
                              : 'Timer resumed',
                        );
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: isBreak
                  ? _ActionButton(
                      icon: LucideIcons.skipForward,
                      label: 'Skip',
                      color: AppTheme.shortBreak,
                      onTap: () {
                        controller.skipCurrentBreak();
                        _showFeedback(context, 'Break skipped');
                      },
                    )
                  : _ActionButton(
                      icon: LucideIcons.zap,
                      label: 'Break Now',
                      color: AppTheme.accent,
                      onTap: () {
                        controller.takeBreakNow();
                        _showFeedback(context, 'Break started');
                      },
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: LucideIcons.moon,
                label: quietModeEnabled ? 'Quiet On' : 'Quiet Mode',
                color: quietModeEnabled
                    ? AppTheme.warning
                    : AppTheme.textPrimary,
                onTap: () {
                  controller.toggleQuietMode();
                  _showFeedback(
                    context,
                    controller.quietModeEnabled
                        ? 'Quiet mode enabled'
                        : 'Quiet mode disabled',
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: LucideIcons.cat,
                label: companionEnabled ? 'Pet On' : 'Companion',
                color: companionEnabled
                    ? AppTheme.success
                    : AppTheme.textPrimary,
                onTap: () {
                  controller.toggleCompanion();
                  _showFeedback(
                    context,
                    controller.companionEnabled
                        ? 'Companion enabled'
                        : 'Companion disabled',
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: LucideIcons.clock3,
                label: 'Snooze 5m',
                color: AppTheme.textPrimary,
                onTap: isBreak
                    ? null
                    : () {
                        controller.snooze(minutes: 5);
                        _showFeedback(context, 'Snoozed for 5 minutes');
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: LucideIcons.clock9,
                label: 'Snooze 15m',
                color: AppTheme.textPrimary,
                onTap: isBreak
                    ? null
                    : () {
                        controller.snooze(minutes: 15);
                        _showFeedback(context, 'Snoozed for 15 minutes');
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: LucideIcons.sunset,
                label: 'Clock Out (Reflection)',
                color: const Color(0xFFF59E0B),
                onTap: () {
                  ClockOutDialog.show(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
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
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.settings,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Dashboard & Settings',
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
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(
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

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.15)
                : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.3)
                  : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.onTap == null ? AppTheme.textMuted : widget.color,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.onTap == null
                      ? AppTheme.textMuted
                      : widget.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
