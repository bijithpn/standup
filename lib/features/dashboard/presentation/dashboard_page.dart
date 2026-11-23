import 'package:breakmate/features/feedback/interruption_feedback_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/timer_section.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/action_grid.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/calendar_section.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/daily_summary_section.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/shared/widgets/page_scroll.dart';
import 'package:breakmate/features/dashboard/presentation/dashboard_controller.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardController(),
      child: PageScroll(
        child: Consumer2<SettingsRepository, DashboardController>(
          builder: (context, settingsRepo, dashboardCtrl, _) {
            final calendarEnabled =
                settingsRepo.currentSettings.calendarEnabled;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DashboardHeader(),
                const SizedBox(height: AppTheme.space32),
                Center(
                  child: TimerSection(
                    calendarEvents: dashboardCtrl.calendarEvents,
                  ),
                ),
                const SizedBox(height: AppTheme.space32),
                Divider(height: 1, color: AppTheme.borderSubtle),
                const SizedBox(height: AppTheme.space24),
                const DailySummarySection(),
                const SizedBox(height: AppTheme.space24),
                Divider(height: 1, color: AppTheme.borderSubtle),
                const SizedBox(height: AppTheme.space24),
                if (calendarEnabled) ...[
                  CalendarSection(
                    calendarEvents: dashboardCtrl.calendarEvents,
                    loading: dashboardCtrl.calendarLoading,
                    permissionGranted: dashboardCtrl.calendarPermissionGranted,
                    permissionDenied: dashboardCtrl.calendarPermissionDenied,
                    isRequestingPermission:
                        dashboardCtrl.isRequestingPermission,
                    onLoadEvents: dashboardCtrl.loadCalendarEvents,
                    onRequestAccess: () async {
                      final granted = await dashboardCtrl
                          .requestCalendarAccess();
                      if (context.mounted) {
                        if (granted) {
                          Toast.showSuccess(context, 'Calendar access granted');
                        } else {
                          Toast.showError(
                            context,
                            'Calendar access denied. Enable it in System Settings.',
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: AppTheme.space24),
                  Divider(height: 1, color: AppTheme.borderSubtle),
                  const SizedBox(height: AppTheme.space16),
                ],
                const ActionGrid(),
                const SizedBox(height: AppTheme.space16),
                InterruptionFeedbackCard(repository: settingsRepo),
              ],
            );
          },
        ),
      ),
    );
  }
}
