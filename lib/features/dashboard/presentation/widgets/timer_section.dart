import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/core/services/calendar_service.dart';

class TimerSection extends StatelessWidget {
  final List<CalendarEvent>? calendarEvents;

  const TimerSection({super.key, this.calendarEvents});

  @override
  Widget build(BuildContext context) {
    return Consumer2<BreakController, SettingsRepository>(
      builder: (context, controller, settingsRepo, child) {
        final engine = controller.timerEngine;
        final settings = settingsRepo.currentSettings;
        final isRunning = engine.state == TimerState.running;
        final isPaused = engine.state == TimerState.paused;
        final isBreak = engine.state == TimerState.breakActive;

        String statusText = AppStrings.readyToFocus;

        if (isRunning) statusText = AppStrings.focusing;
        if (isPaused) statusText = AppStrings.paused;
        if (engine.isPreBreak) statusText = AppStrings.breakComingUp;
        if (isBreak) statusText = 'Break active';

        final nextReason = _nextBreakReason(engine, settingsRepo);
        final statusChips = <_StatusChipData>[
          _StatusChipData(
            settings.intensityLevel.toUpperCase(),
            AppTheme.accent,
          ),
          if (settings.quietModeEnabled)
            _StatusChipData('QUIET', AppTheme.warning),
          if (settings.calendarEnabled)
            _StatusChipData('CALENDAR', const Color(0xFF6366F1)),
          if (settings.companionEnabled)
            _StatusChipData('COMPANION', AppTheme.success),
        ];

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(elevated: true),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 24,
            spacing: 24,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 280, maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(label: statusText, color: AppTheme.accent),
                        for (final chip in statusChips)
                          _StatusChip(label: chip.label, color: chip.color),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<int>(
                      valueListenable: engine.countdownNotifier,
                      builder: (context, seconds, _) {
                        final duration = Duration(seconds: seconds);
                        final mins = duration.inMinutes.toString().padLeft(
                          2,
                          '0',
                        );
                        final secs = (duration.inSeconds % 60)
                            .toString()
                            .padLeft(2, '0');
                        return Text(
                          '$mins:$secs',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            letterSpacing: -2,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      nextReason,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.pauseReason,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      if (isPaused)
                        _SnoozeButton(
                          onTap: () => controller.snooze(minutes: 15),
                          label: '+15m',
                        ),
                      const SizedBox(width: 8),
                      _PrimaryButton(
                        onTap: () => controller.togglePause(),
                        label: isPaused ? AppStrings.resume : AppStrings.pause,
                        icon: isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        isPrimary: true,
                        semanticsLabel: isPaused
                            ? 'Resume focus timer'
                            : 'Pause focus timer',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SecondaryButton(
                    onTap: () => controller.takeBreakNow(),
                    label: AppStrings.takeBreakNow,
                    icon: Icons.coffee_rounded,
                    semanticsLabel: 'Start break immediately',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _nextBreakReason(TimerEngine engine, SettingsRepository settingsRepo) {
    final settings = settingsRepo.currentSettings;
    final conflict = _nextCalendarConflict();
    if (engine.state == TimerState.breakActive) {
      return settings.strictMode
          ? 'This break is enforcing your selected recovery intensity.'
          : 'This break started from your current rhythm and can be skipped if needed.';
    }
    if (engine.isPreBreak) {
      return 'Wrap up now. Your configured pre-break warning is active.';
    }
    if (conflict != null) {
      final minutes = conflict.start.difference(DateTime.now()).inMinutes;
      if (minutes <= 0) {
        return 'Calendar conflict: a meeting is active, so breaks can wait until it ends.';
      }
      return 'Calendar conflict in ${minutes}m. Take a short reset before it starts.';
    }
    if (settings.quietModeEnabled) {
      return 'Quiet mode is on, so BreakMate will keep interruptions restrained.';
    }
    return 'Next break follows your ${settings.shortBreakIntervalMinutes}-minute focus interval.';
  }

  CalendarEvent? _nextCalendarConflict() {
    final events = calendarEvents;
    if (events == null || events.isEmpty) return null;
    final now = DateTime.now();
    for (final event in events) {
      if (event.isAllDay) continue;
      final isLive = event.start.isBefore(now) && event.end.isAfter(now);
      final startsSoon =
          event.start.isAfter(now) &&
          event.start.difference(now) <= const Duration(minutes: 20);
      if (isLive || startsSoon) return event;
    }
    return null;
  }
}

class _StatusChipData {
  final String label;
  final Color color;

  const _StatusChipData(this.label, this.color);
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final bool isPrimary;
  final String? semanticsLabel;

  const _PrimaryButton({
    required this.onTap,
    required this.label,
    required this.icon,
    this.isPrimary = false,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isPrimary ? AppTheme.accent : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPrimary ? AppTheme.accent : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.white : AppTheme.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isPrimary ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnoozeButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _SnoozeButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final String? semanticsLabel;

  const _SecondaryButton({
    required this.onTap,
    required this.label,
    required this.icon,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _PrimaryButton(
      onTap: onTap,
      label: label,
      icon: icon,
      isPrimary: false,
      semanticsLabel: semanticsLabel,
    );
  }
}
