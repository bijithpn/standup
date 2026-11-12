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

        if (isRunning) statusText = 'Focusing';
        if (isPaused) statusText = AppStrings.paused;
        if (engine.isPreBreak) statusText = AppStrings.breakComingUp;
        if (isBreak) statusText = 'Break active';

        final nextReason = _nextBreakReason(engine, settingsRepo);

        final totalSeconds = isBreak
            ? (engine.activeBreak?.durationSeconds ??
                  engine.shortBreakDurationSeconds)
            : engine.shortBreakIntervalMinutes * 60;
        final caption = isBreak
            ? 'left in this break'
            : isPaused
            ? 'until your next break, on hold'
            : 'until your next break';
        final dot = isBreak
            ? AppTheme.shortBreak
            : isPaused
            ? AppTheme.warning
            : AppTheme.success;
        final tags = [
          if (settings.quietModeEnabled) 'Quiet mode',
          if (settings.calendarEnabled) 'Calendar',
          if (settings.companionEnabled) 'Companion',
        ];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: AppTheme.borderSubtle),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (tags.isNotEmpty)
                    Flexible(
                      child: Text(
                        tags.join('  ·  '),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<int>(
                valueListenable: engine.countdownNotifier,
                builder: (context, seconds, _) {
                  final duration = Duration(seconds: seconds);
                  final mins = duration.inMinutes.toString().padLeft(2, '0');
                  final secs = (duration.inSeconds % 60).toString().padLeft(
                    2,
                    '0',
                  );
                  final progress = totalSeconds <= 0
                      ? 0.0
                      : (1 - seconds / totalSeconds).clamp(0.0, 1.0);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$mins:$secs',
                            style: TextStyle(
                              fontSize: 64,
                              height: 1,
                              fontWeight: FontWeight.w300,
                              color: isPaused
                                  ? AppTheme.textMuted
                                  : AppTheme.textPrimary,
                              letterSpacing: -2,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              caption,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          color: dot,
                          backgroundColor: AppTheme.border,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                isPaused ? controller.pauseReason : nextReason,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (isBreak)
                    _PrimaryButton(
                      onTap: () => controller.skipCurrentBreak(),
                      label: 'Skip break',
                      icon: Icons.skip_next_rounded,
                      isPrimary: true,
                    )
                  else ...[
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
                    _SecondaryButton(
                      onTap: () => controller.takeBreakNow(),
                      label: AppStrings.takeBreakNow,
                      icon: Icons.coffee_rounded,
                      semanticsLabel: 'Start break immediately',
                    ),
                  ],
                  if (isPaused)
                    _SnoozeButton(
                      onTap: () => controller.snooze(minutes: 15),
                      label: 'Pause 15 more min',
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
