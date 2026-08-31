import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';

import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/core/utils/toast.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/timer_section.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/action_grid.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/calendar_section.dart';
import 'package:breakmate/features/dashboard/presentation/widgets/daily_summary_section.dart';
import 'package:breakmate/features/settings/settings_repository.dart';
import 'package:breakmate/shared/theme/app_theme.dart';
import 'package:breakmate/features/dashboard/presentation/dashboard_controller.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardController(),
      child: LayoutBuilder(
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
                  child: Consumer2<SettingsRepository, DashboardController>(
                    builder: (context, settingsRepo, dashboardCtrl, _) {
                      final calendarEnabled =
                          settingsRepo.currentSettings.calendarEnabled;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          const DashboardHeader(),
                          const SizedBox(height: 40),
                          TimerSection(calendarEvents: dashboardCtrl.calendarEvents),
                          const SizedBox(height: 40),
                          const ActionGrid(),
                          if (calendarEnabled) ...[
                            const SizedBox(height: 40),
                            CalendarSection(
                              calendarEvents: dashboardCtrl.calendarEvents,
                              loading: dashboardCtrl.calendarLoading,
                              permissionGranted: dashboardCtrl.calendarPermissionGranted,
                              permissionDenied: dashboardCtrl.calendarPermissionDenied,
                              isRequestingPermission: dashboardCtrl.isRequestingPermission,
                              onLoadEvents: dashboardCtrl.loadCalendarEvents,
                              onRequestAccess: () async {
                                final granted = await dashboardCtrl.requestCalendarAccess();
                                if (context.mounted) {
                                  if (granted) {
                                    Toast.showSuccess(context, 'Calendar access granted!');
                                  } else {
                                    Toast.showError(
                                      context,
                                      'Calendar access denied. Please enable it in System Settings.',
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 40),
                          const DailySummarySection(),
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
            toolBar: ToolBar(
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
      ),
    );
  }
}
