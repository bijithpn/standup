import 'package:flutter/material.dart';
import 'package:breakmate/core/constants/app_strings.dart';
import 'package:breakmate/shared/theme/app_theme.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          style: TextStyle(
            fontFamilyFallback: const ['Georgia', 'Times New Roman'],
            fontSize: 34,
            height: 1.1,
            color: AppTheme.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.dashboardSubtitle,
          style: TextStyle(
            fontSize: 14,
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
}
