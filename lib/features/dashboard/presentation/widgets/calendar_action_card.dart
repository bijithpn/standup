import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/minimal_controls.dart';

class CalendarActionCard extends StatelessWidget {
  final CalendarEvent event;

  const CalendarActionCard({super.key, required this.event});

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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppTheme.space12,
            runSpacing: AppTheme.space8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              MinimalButton(
                isSecondary: true,
                onPressed: isLive
                    ? () => controller.snoozeUntil(event.end)
                    : controller.takeBreakNow,
                child: Text(actionLabel),
              ),
            ],
          ),
        );
      },
    );
  }
}
