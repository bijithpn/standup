import 'dart:math' as math;

import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:intl/intl.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/services/app_navigation_service.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/core/services/calendar_service.dart';

const double _ringSize = 132;
const double _wideBreakpoint = 640;

class TimerSection extends StatelessWidget {
  final List<CalendarEvent>? calendarEvents;

  const TimerSection({super.key, this.calendarEvents});

  @override
  Widget build(BuildContext context) {
    return Consumer2<BreakController, SettingsRepository>(
      builder: (context, controller, settingsRepo, child) {
        final engine = controller.timerEngine;
        final isRunning = engine.state == TimerState.running;
        final isPaused = engine.state == TimerState.paused;
        final isBreak = engine.state == TimerState.breakActive;
        final meetingActive = engine.contextManager.isMeetingActive();
        final meetingEnd = _activeMeetingEnd();

        final title = isBreak
            ? 'On a break'
            : engine.isPreBreak
            ? AppStrings.breakComingUp
            : isPaused
            ? AppStrings.paused
            : isRunning
            ? 'Focusing'
            : AppStrings.readyToFocus;

        final totalSeconds = isBreak
            ? (engine.activeBreak?.durationSeconds ??
                  engine.shortBreakDurationSeconds)
            : engine.shortBreakIntervalMinutes * 60;
        final ringColor = isBreak
            ? AppTheme.shortBreak
            : isPaused
            ? AppTheme.textMuted
            : AppTheme.accent;
        final showDetectionLink = isPaused || meetingActive;

        final ring = ValueListenableBuilder<int>(
          valueListenable: engine.countdownNotifier,
          builder: (context, seconds, _) {
            final duration = Duration(seconds: seconds);
            final mins = duration.inMinutes.toString().padLeft(2, '0');
            final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
            final progress = totalSeconds <= 0
                ? 0.0
                : (1 - seconds / totalSeconds).clamp(0.0, 1.0);
            return Semantics(
              label:
                  '${duration.inMinutes} minutes ${duration.inSeconds % 60} seconds remaining',
              excludeSemantics: true,
              child: SizedBox.square(
                dimension: _ringSize,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: progress,
                    track: AppTheme.borderSubtle,
                    color: ringColor,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space16,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$mins:$secs',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 32,
                            height: 1,
                            fontWeight: FontWeight.w400,
                            fontFeatures: AppTheme.tabular,
                            color: isPaused
                                ? AppTheme.textMuted
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            final align = wide
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center;
            final details = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: align,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                ValueListenableBuilder<int>(
                  valueListenable: engine.countdownNotifier,
                  builder: (context, seconds, _) => Text(
                    _reason(controller, settingsRepo, seconds),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                _actions(
                  controller,
                  isPaused,
                  isBreak,
                  meetingEnd,
                  wide,
                  showDetectionLink,
                ),
              ],
            );
            if (!wide) {
              return Column(
                children: [
                  ring,
                  const SizedBox(height: AppTheme.space24),
                  details,
                ],
              );
            }
            return Row(
              children: [
                ring,
                const SizedBox(width: AppTheme.space32),
                Expanded(child: details),
              ],
            );
          },
        );
      },
    );
  }

  Widget _actions(
    BreakController controller,
    bool isPaused,
    bool isBreak,
    DateTime? meetingEnd,
    bool wide,
    bool showDetectionLink,
  ) {
    final engine = controller.timerEngine;
    return Wrap(
      alignment: wide ? WrapAlignment.start : WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppTheme.space12,
      runSpacing: AppTheme.space8,
      children: [
        if (isBreak)
          MinimalButton(
            onPressed: controller.skipCurrentBreak,
            child: const Text('Skip break'),
          )
        else ...[
          MinimalButton(
            onPressed: controller.togglePause,
            child: Text(isPaused ? AppStrings.resume : AppStrings.pause),
          ),
          MinimalButton(
            isSecondary: true,
            onPressed: controller.takeBreakNow,
            child: const Text(AppStrings.takeBreakNow),
          ),
        ],
        if (!isBreak && !controller.isFocusSessionActive)
          PopupMenuButton<int>(
            tooltip: 'Snooze reminders',
            onSelected: (minutes) {
              if (minutes == -1 && meetingEnd != null) {
                controller.snoozeUntil(meetingEnd);
              } else {
                controller.snooze(minutes: minutes);
              }
            },
            itemBuilder: (context) => [
              for (final minutes in [2, 5, 15])
                PopupMenuItem(
                  value: minutes,
                  child: Text(
                    '$minutes minutes · resume ${DateFormat.jm().format(DateTime.now().add(Duration(minutes: minutes)))}',
                  ),
                ),
              if (meetingEnd != null)
                PopupMenuItem(
                  value: -1,
                  child: Text(
                    'After this meeting · ${DateFormat.jm().format(meetingEnd)}',
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Snooze',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 12,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        if (showDetectionLink)
          MinimalButton(
            isGhost: true,
            onPressed: () => sl<AppNavigationService>().openSection(
              engine.contextManager.isWithinWorkingHours()
                  ? 'Intelligent Detection'
                  : 'General',
            ),
            child: const Text('Open detection settings'),
          ),
      ],
    );
  }

  String _reason(
    BreakController controller,
    SettingsRepository settingsRepo,
    int seconds,
  ) {
    final engine = controller.timerEngine;
    final ctx = engine.contextManager;
    final now = DateTime.now();
    String at(DateTime t) => DateFormat.jm().format(t);

    if (engine.state == TimerState.breakActive) {
      return settingsRepo.currentSettings.strictMode
          ? 'Strict controls are enforced.'
          : 'Skip is available if you need it.';
    }
    if (engine.state == TimerState.paused) {
      final snoozeEnd = controller.snoozeResumeAt;
      if (snoozeEnd != null) return 'Snoozed until ${at(snoozeEnd)}.';
      if (controller.isFocusSessionActive) {
        return 'Focus session active. Resumes when it ends.';
      }
      if (engine.isManuallyPaused) return 'Paused manually.';
      if (!ctx.isWithinWorkingHours()) {
        final next = ctx.nextWorkingTime();
        if (next == null) return 'Outside working hours.';
        final sameDay = DateUtils.isSameDay(next, now);
        final when = sameDay
            ? at(next)
            : DateFormat('EEE, h:mm a').format(next);
        return 'Outside working hours. Resumes $when.';
      }
      if (ctx.isSmartPauseActive()) {
        return ctx.isPresentationActive()
            ? 'Presentation detected. Resumes when it ends.'
            : 'Video playback detected. Resumes when it ends.';
      }
      return 'Paused.';
    }
    if (engine.isPreBreak) return 'Wrap up. Your break is about to start.';
    if (ctx.isMeetingActive()) {
      return 'In a meeting. Breaks use quiet reminders.';
    }
    final conflict = _nextCalendarConflict();
    if (conflict != null) {
      final minutes = conflict.start.difference(now).inMinutes;
      return minutes <= 0
          ? 'Calendar event active. Breaks use quiet reminders.'
          : 'Calendar event in $minutes min. Take a reset first.';
    }
    if (engine.state == TimerState.running) {
      return 'Next break at ${at(now.add(Duration(seconds: seconds)))}.';
    }
    return 'Break every ${engine.shortBreakIntervalMinutes} min.';
  }

  DateTime? _activeMeetingEnd() {
    final now = DateTime.now();
    final events =
        (calendarEvents ?? <CalendarEvent>[])
            .where((e) => !e.isAllDay && e.end.isAfter(now))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    DateTime? end;
    for (final event in events) {
      if (event.start.isAfter(end ?? now)) break;
      if (end == null || event.end.isAfter(end)) end = event.end;
    }
    return end;
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

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color color;

  const _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
    if (progress > 0) {
      paint
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color;
}
