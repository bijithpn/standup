import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:flutter/material.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/app/dependency_injection.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/calendar_event_row.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/calendar_action_card.dart';

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
                  Text(
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
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accent,
                  ),
                )
              else
                TapTarget(
                  semanticLabel: 'Refresh calendar events',
                  onTap: onLoadEvents,
                  child: Icon(
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
      return Padding(
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
          CalendarActionCard(event: conflict),
          const SizedBox(height: 24),
        ],
        for (var date in sortedDates) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Text(
              _formatDate(date),
              style: TextStyle(
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
                CalendarEventRow(event: event),
                if (event != groupedEvents[date]!.last)
                  Padding(
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
                      style: TextStyle(
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
              TapTarget(
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
                TapTarget(
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
                    child: Text(
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
