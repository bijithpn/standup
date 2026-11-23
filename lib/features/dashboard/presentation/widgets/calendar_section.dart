import 'package:breakmate/shared/widgets/minimal_controls.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Up next',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
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
              Tooltip(
                message: 'Refresh calendar events',
                child: TapTarget(
                  semanticLabel: 'Refresh calendar events',
                  onTap: onLoadEvents,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.space8),
                    child: Icon(
                      CupertinoIcons.refresh,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        _buildCalendarContent(),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
        child: Text(
          'No events in the next 8 hours — focus time!',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
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
          Divider(height: 1, color: AppTheme.borderSubtle),
        ],
        for (var date in sortedDates) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 12),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ...groupedEvents[date]!.map((event) {
            return Column(
              children: [
                CalendarEventRow(event: event),
                if (event != groupedEvents[date]!.last)
                  Divider(height: 1, color: AppTheme.borderSubtle),
              ],
            );
          }),
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

    if (date == today) return 'Today';
    if (date == tomorrow) return 'Tomorrow';

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
        ? CupertinoIcons.exclamationmark_circle
        : CupertinoIcons.lock;
    final color = permissionDenied ? AppTheme.error : AppTheme.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Wrap(
            spacing: AppTheme.space8,
            runSpacing: AppTheme.space8,
            children: [
              MinimalButton(
                onPressed: isRequestingPermission ? null : onRequestAccess,
                child: Text(
                  isRequestingPermission
                      ? 'Requesting...'
                      : (permissionDenied ? 'Try Again' : 'Grant Access'),
                ),
              ),
              if (permissionDenied && !isRequestingPermission)
                MinimalButton(
                  isSecondary: true,
                  onPressed: () => sl<CalendarService>().openSettings(),
                  child: const Text('Open Settings'),
                ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: double.infinity, height: 16, radius: 4),
                    SizedBox(height: 8),
                    _SkeletonBox(width: 120, height: 12, radius: 4),
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
