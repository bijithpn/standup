import 'dart:async';

import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/core/services/timer_engine.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/analytics/stats_model.dart';
import 'package:breakmate/features/analytics/stats_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  List<CalendarEvent>? _calendarEvents;
  bool _calendarLoading = false;
  bool _calendarPermissionGranted = false;
  bool _calendarPermissionDenied = false;
  bool _isRequestingPermission = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCalendarEvents();
    // Refresh calendar events every 2 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _loadCalendarEvents();
    });

    // Listen for setting changes to refresh calendar data if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        sl<SettingsRepository>().addListener(_handleSettingsChange);
      }
    });
  }

  void _handleSettingsChange() {
    if (mounted) {
      _loadCalendarEvents();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCalendarEvents();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    sl<SettingsRepository>().removeListener(_handleSettingsChange);
    super.dispose();
  }

  Future<void> _loadCalendarEvents() async {
    final settings = sl<SettingsRepository>().currentSettings;
    if (!settings.calendarEnabled) {
      setState(() {
        _calendarEvents = null;
        _calendarLoading = false;
      });
      return;
    }

    final calendarService = sl<CalendarService>();
    if (mounted) {
      setState(() => _calendarLoading = true);
    }

    try {
      final hasPermission = await calendarService.checkPermissions();
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _calendarPermissionGranted = false;
            _calendarLoading = false;
          });
        }
        return;
      }

      _calendarPermissionGranted = true;
      _calendarPermissionDenied = false; // Reset if confirmed
      
      // Query events for the entire current day (from start of today to end of today)
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      final events = await calendarService.getEvents(startOfToday, endOfToday);
      if (mounted) {
        setState(() {
          _calendarEvents = events;
          _calendarLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _calendarLoading = false);
      }
    }
  }

  Future<void> _requestCalendarAccess() async {
    if (_isRequestingPermission) return;

    setState(() => _isRequestingPermission = true);

    try {
      final calendarService = sl<CalendarService>();
      final granted = await calendarService.requestPermissions();

      if (mounted) {
        if (granted) {
          setState(() {
            _calendarPermissionGranted = true;
            _calendarPermissionDenied = false;
          });
          Toast.showSuccess(context, 'Calendar access granted!');
          await _loadCalendarEvents();
        } else {
          setState(() {
            _calendarPermissionGranted = false;
            _calendarPermissionDenied = true;
          });
          Toast.showError(
            context,
            'Calendar access denied. Please enable it in System Settings.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Toast.showError(context, 'An unexpected error occurred.');
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingPermission = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final padding = isSmall ? 20.0 : 40.0;

        Widget buildContent(ScrollController? scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.all(padding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Consumer<SettingsRepository>(
                  builder: (context, settingsRepo, _) {
                    final calendarEnabled =
                        settingsRepo.currentSettings.calendarEnabled;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        _buildHeader(context),
                        const SizedBox(height: 40),
                        _buildTimerSection(context),
                        const SizedBox(height: 40),
                        _buildActionGrid(context),
                        if (calendarEnabled) ...[
                          const SizedBox(height: 40),
                          _buildCalendarSection(context),
                        ],
                        const SizedBox(height: 40),
                        _buildSummarySection(context),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        }

        if (isSmall) {
          return Scaffold(
            backgroundColor: AppTheme.surface,
            body: SafeArea(child: buildContent(null)),
          );
        }

        return MacosScaffold(
          backgroundColor: AppTheme.surface,
          toolBar: const ToolBar(
            title: Text(
              AppStrings.today,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            titleWidth: 260,
            actions: [],
          ),
          children: [
            ContentArea(
              builder: (context, scrollController) =>
                  buildContent(scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          AppStrings.dashboardSubtitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.goodMorning;
    if (hour < 17) return AppStrings.goodAfternoon;
    return AppStrings.goodEvening;
  }

  Widget _buildTimerSection(BuildContext context) {
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
                          style: const TextStyle(
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
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.pauseReason,
                      style: const TextStyle(
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
    final events = _calendarEvents;
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

  Widget _buildActionGrid(BuildContext context) {
    return Consumer<BreakController>(
      builder: (context, controller, _) {
        final companionActive = controller.companionEnabled;

        return Row(
          children: [
            Expanded(
              child: _ActionCard(
                title: AppStrings.companion,
                subtitle: companionActive
                    ? (controller.timerEngine.state == TimerState.running
                          ? 'Active and watching'
                          : 'Resting')
                    : 'Disabled in settings',
                icon: Icons.pets_rounded,
                isActive: companionActive,
                onTap: () => controller.toggleCompanion(),
                semanticsLabel: 'Toggle desktop companion',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionCard(
                title: AppStrings.quietMode,
                subtitle: controller.quietModeEnabled
                    ? 'All alerts silenced'
                    : 'Notifications on',
                icon: Icons.do_not_disturb_on_rounded,
                isActive: controller.quietModeEnabled,
                onTap: () => controller.toggleQuietMode(),
                semanticsLabel: 'Toggle quiet mode',
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Calendar Events Section
  // ---------------------------------------------------------------------------

  Widget _buildCalendarSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Upcoming Events',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_calendarLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accent,
                  ),
                )
              else
                GestureDetector(
                  onTap: _loadCalendarEvents,
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCalendarContent(),
        ],
      ),
    );
  }

  Widget _buildCalendarContent() {
    if (_calendarLoading) {
      return _buildCalendarSkeleton();
    }

    if (!_calendarPermissionGranted) {
      return _buildCalendarPermissionPrompt();
    }

    final events = _calendarEvents;

    if (events == null || events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: 10),
            Text(
              'No events in the next 8 hours — focus time!',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    // Group events by date
    final groupedEvents = <DateTime, List<CalendarEvent>>{};
    for (var event in events) {
      final date = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      groupedEvents.putIfAbsent(date, () => []).add(event);
    }

    final sortedDates = groupedEvents.keys.toList()..sort();
    final conflict = _nextCalendarConflict();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (conflict != null) ...[
          _CalendarActionCard(event: conflict),
          const SizedBox(height: 24),
        ],
        for (var date in sortedDates) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Text(
              _formatDate(date),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...groupedEvents[date]!.map((event) {
            return Column(
              children: [
                _CalendarEventRow(event: event),
                if (event != groupedEvents[date]!.last)
                  const Padding(
                    padding: EdgeInsets.only(left: 54),
                    child: Divider(height: 1, color: AppTheme.border),
                  ),
              ],
            );
          }),
          if (date != sortedDates.last) const SizedBox(height: 16),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    if (date == today) return 'TODAY';
    if (date == tomorrow) return 'TOMORROW';

    final months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  Widget _buildCalendarPermissionPrompt() {
    final title = _calendarPermissionDenied ? 'Calendar access denied' : 'Calendar access required';
    final subtitle = _calendarPermissionDenied
        ? 'Please enable calendar access in System Settings to see your events. If already enabled, toggle it OFF and ON again to refresh the system cache.'
        : 'Calendar access required to show upcoming events and avoid interrupting your meetings.';
    final icon = _calendarPermissionDenied
        ? Icons.error_outline_rounded
        : Icons.lock_outline_rounded;
    final color = _calendarPermissionDenied
        ? AppTheme.error
        : AppTheme.warning;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: _isRequestingPermission ? null : _requestCalendarAccess,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: _isRequestingPermission ? 0.05 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isRequestingPermission) ...[
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        _isRequestingPermission
                            ? 'Requesting...'
                            : (_calendarPermissionDenied ? 'Try Again' : 'Grant Access'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366F1),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_calendarPermissionDenied && !_isRequestingPermission) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => sl<CalendarService>().openSettings(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.25)),
                    ),
                    child: const Text(
                      'Open Settings',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSkeleton() {
    return Column(
      children: List.generate(
        2,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _SkeletonBox(width: 40, height: 40, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: double.infinity, height: 14, radius: 4),
                    const SizedBox(height: 6),
                    _SkeletonBox(width: 120, height: 11, radius: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Consumer<StatsService>(
      builder: (context, statsService, child) {
        final stats = statsService.load();
        final todayStr = _todayString();
        final todayStats = stats.weeklyData.lastWhere(
          (d) => d.date == todayStr,
          orElse: () => DailyStats(
            date: todayStr,
            breaksCompleted: 0,
            breaksSkipped: 0,
            usageMinutes: 0,
          ),
        );

        final hasData =
            todayStats.breaksCompleted > 0 ||
            todayStats.breaksSkipped > 0 ||
            todayStats.usageMinutes > 0;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    AppStrings.todayActivity,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (hasData) _RecommendationChip(stats: stats),
                ],
              ),
              const SizedBox(height: 24),
              if (!hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      AppStrings.noActivityRecorded,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                ValueListenableBuilder<Duration>(
                  valueListenable: sl<TimerEngine>().totalWorkTodayNotifier,
                  builder: (context, workToday, _) {
                    final hours = workToday.inHours;
                    final minutes = workToday.inMinutes % 60;
                    final seconds = workToday.inSeconds % 60;

                    String focusTimeStr;
                    if (hours > 0) {
                      focusTimeStr = '${hours}h ${minutes}m';
                    } else if (minutes > 0) {
                      focusTimeStr = '${minutes}m ${seconds}s';
                    } else {
                      focusTimeStr = '${seconds}s';
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: AppStrings.completed,
                          value: '${todayStats.breaksCompleted}',
                          color: AppTheme.success,
                        ),
                        _StatItem(
                          label: AppStrings.skipped,
                          value: '${todayStats.breaksSkipped}',
                          color: AppTheme.error,
                        ),
                        _StatItem(
                          label: AppStrings.focusTimeMins,
                          value: focusTimeStr,
                          color: AppTheme.warning,
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Calendar Event Row Widget
// ---------------------------------------------------------------------------

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

class _CalendarActionCard extends StatelessWidget {
  final CalendarEvent event;

  const _CalendarActionCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLive = event.start.isBefore(now) && event.end.isAfter(now);
    final title = isLive
        ? 'Meeting is active'
        : 'Meeting starts in ${event.start.difference(now).inMinutes.clamp(1, 999)}m';
    final actionLabel = isLive
        ? 'Snooze until meeting ends'
        : 'Take break before meeting';

    return Consumer<BreakController>(
      builder: (context, controller, _) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                color: Color(0xFF6366F1),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SmallActionButton(
                label: actionLabel,
                onTap: isLive
                    ? () => controller.snoozeUntil(event.end)
                    : () => controller.takeBreakNow(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SmallActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CalendarEventRow extends StatelessWidget {
  final CalendarEvent event;

  const _CalendarEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isHappeningNow =
        !event.isAllDay && event.start.isBefore(now) && event.end.isAfter(now);
    final isUpcoming = event.start.isAfter(now);
    final minutesUntil = event.start.difference(now).inMinutes;

    final timeLabel = event.isAllDay
        ? 'All day'
        : '${_formatTime(event.start)} – ${_formatTime(event.end)}';

    String? badge;
    Color badgeColor = AppTheme.accent;
    if (isHappeningNow) {
      badge = 'Live';
      badgeColor = AppTheme.error;
    } else if (isUpcoming && minutesUntil <= 15) {
      badge = 'In ${minutesUntil}m';
      badgeColor = AppTheme.warning;
    } else if (isUpcoming && minutesUntil <= 60) {
      badge = 'In ${minutesUntil}m';
      badgeColor = const Color(0xFF6366F1);
    }

    final meetingPlatform = event.getMeetingPlatform();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Time indicator
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isHappeningNow
                  ? AppTheme.error.withValues(alpha: 0.1)
                  : const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isHappeningNow
                  ? Icons.fiber_manual_record_rounded
                  : Icons.event_rounded,
              size: 20,
              color: isHappeningNow ? AppTheme.error : const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isHappeningNow
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (meetingPlatform != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          meetingPlatform,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6366F1),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:$m $period';
  }
}

// ---------------------------------------------------------------------------
// Skeleton loading box
// ---------------------------------------------------------------------------

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _RecommendationChip extends StatelessWidget {
  final StatsModel stats;
  const _RecommendationChip({required this.stats});

  @override
  Widget build(BuildContext context) {
    String recommendation = 'Keep it up!';
    if (stats.completionRate < 0.5 && stats.breaksCompleted > 2) {
      recommendation = 'High skips. Try a longer interval?';
    } else if (stats.dailyUsageMinutes > 120 && stats.wellnessScore < 40) {
      recommendation = 'Intense day. Take a long break?';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        recommendation,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme.accent,
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
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final String? semanticsLabel;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isActive = true,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? '$title: $subtitle',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.accent.withValues(alpha: 0.1)
                      : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isActive ? AppTheme.accent : AppTheme.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
