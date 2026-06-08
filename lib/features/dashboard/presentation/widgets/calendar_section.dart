import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/app/dependency_injection.dart';

class CalendarSection extends StatelessWidget {
  final List<CalendarEvent>? calendarEvents;
  final bool loading;
  final bool permissionGranted;
  final bool permissionDenied;
  final bool isRequestingPermission;
  final VoidCallback onLoadEvents;
  final VoidCallback onRequestAccess;

  const CalendarSection({
    super.key,
    required this.calendarEvents,
    required this.loading,
    required this.permissionGranted,
    required this.permissionDenied,
    required this.isRequestingPermission,
    required this.onLoadEvents,
    required this.onRequestAccess,
  });

  @override
  Widget build(BuildContext context) {
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
              if (loading)
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
                  onTap: onLoadEvents,
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
    if (loading) {
      return _buildCalendarSkeleton();
    }

    if (!permissionGranted) {
      return _buildCalendarPermissionPrompt();
    }

    final events = calendarEvents;

    if (events == null || events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: AppTheme.textMuted,
            ),
            SizedBox(width: 10),
            Text(
              'No events in the next 8 hours — focus time!',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
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
    final title = permissionDenied
        ? 'Calendar access denied'
        : 'Calendar access required';
    final subtitle = permissionDenied
        ? 'Please enable calendar access in System Settings to see your events. If already enabled, toggle it OFF and ON again to refresh the system cache.'
        : 'Calendar access required to show upcoming events and avoid interrupting your meetings.';
    final icon = permissionDenied
        ? Icons.error_outline_rounded
        : Icons.lock_outline_rounded;
    final color = permissionDenied ? AppTheme.error : AppTheme.warning;

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
                onTap: isRequestingPermission ? null : onRequestAccess,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF6366F1,
                    ).withValues(alpha: isRequestingPermission ? 0.05 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRequestingPermission) ...[
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
                        isRequestingPermission
                            ? 'Requesting...'
                            : (permissionDenied ? 'Try Again' : 'Grant Access'),
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
              if (permissionDenied && !isRequestingPermission) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => sl<CalendarService>().openSettings(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.textSecondary.withValues(alpha: 0.25),
                      ),
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
        (i) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _SkeletonBox(width: 40, height: 40, radius: 8),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: double.infinity, height: 14, radius: 4),
                    SizedBox(height: 6),
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
                          color: const Color(
                            0xFF6366F1,
                          ).withValues(alpha: 0.12),
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
