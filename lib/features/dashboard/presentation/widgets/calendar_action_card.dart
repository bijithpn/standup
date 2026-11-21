import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:breakmate/core/services/calendar_service.dart';
import 'package:breakmate/features/break_system/application/break_controller.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

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
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.calendar_badge_plus,
                color: AppTheme.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
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
              ),
              const SizedBox(width: 12),
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
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        focusColor: AppTheme.onAccent.withValues(alpha: 0.2),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}
