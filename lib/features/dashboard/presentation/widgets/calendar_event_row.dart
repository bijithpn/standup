import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class CalendarEventRow extends StatelessWidget {
  final CalendarEvent event;

  const CalendarEventRow({super.key, required this.event});

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
      badgeColor = AppTheme.accent;
    }

    final meetingPlatform = event.getMeetingPlatform();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isHappeningNow
                  ? AppTheme.error.withValues(alpha: 0.1)
                  : AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isHappeningNow
                  ? CupertinoIcons.circle_fill
                  : CupertinoIcons.calendar,
              size: 20,
              color: isHappeningNow ? AppTheme.error : AppTheme.accent,
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
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (meetingPlatform != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXs,
                          ),
                        ),
                        child: Text(
                          meetingPlatform,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.accent,
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXs,
                          ),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFeatures: AppTheme.tabular,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontFeatures: AppTheme.tabular,
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
